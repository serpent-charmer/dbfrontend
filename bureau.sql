use bureau;
drop table if exists reputation_change;
drop table if exists reputation;
DROP table IF EXISTS contract;
DROP table IF EXISTS vacancy ;
DROP table IF EXISTS employer;
DROP table IF EXISTS employee;

CREATE TABLE employer (
			id INT(11) AUTO_INCREMENT,
            name VARCHAR(255) NOT NULL,
            address VARCHAR(255) NOT NULL,
            phone_number VARCHAR(255) NOT NULL,
            PRIMARY KEY(id)
        ) CHARACTER SET utf8mb4;
        
CREATE TABLE employee (
			id INT(11) AUTO_INCREMENT,
            name VARCHAR(255) NOT NULL,
            surname VARCHAR(255) NOT NULL,
            third_name VARCHAR(255) NOT NULL,
            profession VARCHAR(255) NOT NULL,
            email VARCHAR(255) NOT NULL,
            PRIMARY KEY(id)
        ) CHARACTER SET utf8mb4;
        
CREATE TABLE vacancy (
			id INT(11) AUTO_INCREMENT,
            job_desc VARCHAR(255) NOT NULL,
            experience INT(11) NOT NULL,
            salary INT(11) NOT NULL,
            ref_employer INT(11) NOT NULL,
            PRIMARY KEY(id),
			FOREIGN KEY(ref_employer) REFERENCES employer (id),
            CONSTRAINT no_trainee_testers CHECK 
            (job_desc NOT IN ('Тестировщик') AND experience >= 1) 
) CHARACTER SET utf8mb4;

CREATE TABLE contract (
			id INT(11) AUTO_INCREMENT,
            ref_employee INT(11) NOT NULL,
            ref_vacancy INT(11) NOT NULL,
            comissions INT(11) NOT NULL CHECK(comissions > 100),
            payed BOOL DEFAULT FALSE,
            PRIMARY KEY(id),
            FOREIGN KEY(ref_employee) REFERENCES employee (id),
            FOREIGN KEY(ref_vacancy) REFERENCES vacancy (id)
        ) CHARACTER SET utf8mb4;
        

create table reputation (
	id int auto_increment,
    ref_employer_id int,
    amt int default 0,
    primary key(id),
    foreign key(ref_employer_id) references employer(id)
) CHARACTER SET utf8mb4;

create table reputation_change(
	rep_change int,
    ref_employer int not null,
    foreign key(ref_employer) references employer(id)
);

delimiter //
CREATE TRIGGER rep_check after INSERT ON employer
       FOR EACH ROW
       BEGIN
            insert into reputation (ref_employer_id) values(NEW.id);
       END;//
delimiter ;


drop procedure if exists vacancy_status_condition_SoftwareEng;
delimiter //
create procedure vacancy_status_condition_SoftwareEng(
IN employer_id int,
IN job_desc VARCHAR(255) CHARACTER SET utf8mb4,
IN exp INT,
IN salary INT)
begin
	if @job_desc in ( 'Программист' ) and @exp >= 2 and @salary < 5000 then
		insert into reputation_change(rep_change, ref_employer) values (-1, @employer_id);
    end if;
end//
delimiter ;


drop procedure if exists vacancy_status_condition_MinReq;
delimiter //
create procedure vacancy_status_condition_MinReq(
IN employer_id int,
IN job_desc VARCHAR(255) CHARACTER SET utf8mb4,
IN exp INT,
IN salary INT)
begin
	if @salary < 1500 then
		insert into reputation_change(rep_change, ref_employer) values (-1, @employer_id);
    end if;
end//
delimiter ;

drop procedure if exists run_status_condition;
delimiter //
create procedure run_status_condition(
IN employer_id int,
IN job_desc VARCHAR(255) CHARACTER SET utf8mb4,
IN exp INT,
IN salary INT)
begin
	declare proc_name VARCHAR(255);
    declare query_str VARCHAR(255);
	declare done int DEFAULT FALSE;
	declare cur2 CURSOR FOR (select routine_name from 
    INFORMATION_SCHEMA.ROUTINES WHERE 
    ROUTINE_NAME LIKE '%vacancy_status_condition%');
	declare CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
	OPEN cur2;
	 read_loop: LOOP
		FETCH cur2 INTO proc_name;
		IF DONE THEN
			LEAVE read_loop;
		ELSE
			set @query_str = concat('call', ' ', proc_name, '(?, ?, ?, ?)');
			prepare stmt from @query_str;
            set @employer_id = employer_id;
			set @job_desc = job_desc;
			set @exp = exp;
			set @salary = salary;
			execute stmt using @employer_id, @job_desc, @exp, @salary;
		END IF;
	 END LOOP;
	 CLOSE cur2;
end//
delimiter ;

            
DROP procedure IF EXISTS CREATE_CONTRACT;
DELIMITER //
CREATE PROCEDURE CREATE_CONTRACT (IN employer_name VARCHAR(255) CHARSET utf8mb4, 
									IN employee_id INT(11),
									IN profession VARCHAR(255) CHARSET utf8mb4,
									IN comissions INT(11))
       BEGIN
       DECLARE EXIT HANDLER FOR SQLEXCEPTION
			  BEGIN
				ROLLBACK;
				SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = "Возникла ошибка при добавлении";
			  END;
			  START TRANSACTION;
              BEGIN
                DECLARE vid INT DEFAULT NULL;
				SET vid = (select id from vacancy where ref_employer = 
                (select id from employer where name = employer_name) and job_desc = profession);
         if(vid IS NOT NULL) then
            INSERT INTO contract (ref_employee, ref_vacancy, comissions) 
			 VALUES(
			 employee_id,
			 vid, comissions);
		 else
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Отсутствует такая вакансия';
         end if;
         END;
			  COMMIT;
       END//
DELIMITER ;

DROP procedure IF EXISTS CREATE_VACANCY;
DELIMITER //
CREATE PROCEDURE CREATE_VACANCY (IN employer_name VARCHAR(255) CHARSET utf8mb4,  
									IN job_desc VARCHAR(255) CHARSET utf8mb4,
                                    IN experience INT(11),
                                    IN salary INT(11))
       BEGIN
         declare ref_employer int;
         declare rep_change int;
         set @ref_employer = (select id from employer where name = employer_name);
		 INSERT INTO vacancy (job_desc, experience, ref_employer, salary) 
         VALUES(job_desc, experience, @ref_employer, salary);
         call run_status_condition(@ref_employer, job_desc, experience, salary);
         set @rep_change = (select sum(reputation_change.rep_change) from reputation_change 
         where reputation_change.ref_employer = @ref_employer);
         if(@rep_change is not null) then
			update reputation set reputation.amt = reputation.amt + @rep_change where ref_employer_id = @ref_employer;
			delete from reputation_change where reputation_change.ref_employer = @ref_employer;
         end if;
         
         
       END//
DELIMITER ;

DROP procedure IF EXISTS CREATE_VACANCY_API;
DELIMITER //
CREATE PROCEDURE CREATE_VACANCY_API (IN employer_id INT(11),  
									IN job_desc VARCHAR(255) CHARSET utf8mb4,
                                    IN experience INT(11),
                                    IN salary INT(11))
       BEGIN
		 INSERT INTO vacancy (job_desc, experience, ref_employer, salary) VALUES(job_desc, experience, employer_id, salary);
       END//
DELIMITER ;

DROP VIEW IF EXISTS GET_JOBS_ALL;
CREATE VIEW GET_JOBS_ALL AS SELECT 
job_desc, name, experience, salary from vacancy 
left join employer on vacancy.ref_employer = employer.id;

DROP VIEW IF EXISTS GET_JOBS;
CREATE VIEW GET_JOBS AS SELECT 
job_desc, lf1.name, experience, salary from vacancy 
left join 
(select employer.id, employer.name, reputation.amt from employer 
left join reputation on employer.id = reputation.ref_employer_id) lf1
on vacancy.ref_employer = lf1.id where lf1.amt >= 0;

DROP VIEW IF EXISTS EMPLOYER_VIEW;
CREATE VIEW EMPLOYER_VIEW AS SELECT employer.name, employer.address, employer.phone_number from employer;

DROP VIEW IF EXISTS EMPLOYEE_VIEW;
CREATE VIEW EMPLOYEE_VIEW AS SELECT employee.name, surname, third_name, profession, email from employee;

DROP procedure IF EXISTS GET_CONTRACTS;
DELIMITER //
CREATE PROCEDURE GET_CONTRACTS()
       BEGIN
         select vacancy.job_desc, employer.name, employee.name, employee.surname, contract.comissions from 
         contract left join vacancy on contract.ref_vacancy = vacancy.id
         left join employer on vacancy.ref_employer = employer.id
         left join employee on contract.ref_employee = employee.id;
       END//
DELIMITER ;

DROP procedure IF EXISTS PAY_CONTRACT;
DELIMITER //
CREATE PROCEDURE PAY_CONTRACT(ref_id INT)
       BEGIN
			update contract set payed = 1 where id = ref_id;
	   END//
DELIMITER ;

DROP procedure IF EXISTS REPORT_PROFS;
DELIMITER //
CREATE PROCEDURE REPORT_PROFS()
       BEGIN
         DECLARE prof VARCHAR(255);
         DECLARE rs TEXT DEFAULT "";
         DECLARE done int DEFAULT FALSE;
         DECLARE cur2 CURSOR FOR SELECT profession FROM employee GROUP BY profession;
		 DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
         OPEN cur2;
         
         read_loop: LOOP
			FETCH cur2 INTO prof;
            IF DONE THEN
				LEAVE read_loop;
			ELSE
                SET rs = CONCAT(rs, prof, ";");
            END IF;
            
         END LOOP;
         
         CLOSE cur2;
         
         SELECT rs as "Список профессий";
         
	  END//
DELIMITER ;




delimiter //
CREATE TRIGGER upd_check BEFORE INSERT ON contract
       FOR EACH ROW
       BEGIN
			declare rep_amt int;
			set @amt = (select amt from reputation where reputation.ref_employer_id =
			(select ref_employer from vacancy where vacancy.id = NEW.ref_vacancy));
            if @amt < 0 then
				set NEW.comissions = NEW.comissions * abs(@amt);
            end if;
       END;//
delimiter ;

delimiter //
CREATE TRIGGER del_check BEFORE DELETE ON contract
       FOR EACH ROW
       BEGIN
            if(OLD.payed IS FALSE) then
				SET @s = CONCAT("Обнаружен неоплаченный контракт");
				SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @s;
            end if;
       END;//
delimiter ;

INSERT INTO EMPLOYER_VIEW (name, address, phone_number) VALUES
			("Дом отдыха и трудоустройства молодежи", "Ильинская 423", "4800-55-91"),
            ("ООО-ГУПНИИПТЕПЛОЦЕНТРАЛЬ", "Бородинская 21", "800-35-91"),
            ("ОАО Рога И Копыта", "Ивановская 91/5", "1800-35-91");
		
INSERT INTO EMPLOYEE_VIEW (name, surname, third_name, profession, email) VALUES
            ("Иван", "Иванович", "Иванов", "Слесарь", "ivanov@mail.ru"),
            ("Иван", "Иванович", "Грепов", "Слесарь", "ivanov423423@mail.ru"),
            ("Глеб", "Иванович", "Грепов", "Программист", "glebo423423@mail.ru"),
            ("Петр", "Сергеевич", "Алишеров", "Бухгалтер", "verkLPO31314@mail.ru");

CALL CREATE_VACANCY("ООО-ГУПНИИПТЕПЛОЦЕНТРАЛЬ", "ФинТех Аналитик", 5, 25000);
CALL CREATE_VACANCY("ООО-ГУПНИИПТЕПЛОЦЕНТРАЛЬ", "Программист", 2, 35000);
CALL CREATE_VACANCY("ОАО Рога И Копыта", "ФинТех Аналитик", 4, 7150);
CALL CREATE_VACANCY("ОАО Рога И Копыта", "Программист", 3, 1150);
CALL CREATE_CONTRACT("ОАО Рога И Копыта", 1, "Программист", 1150);
CALL CREATE_CONTRACT("ООО-ГУПНИИПТЕПЛОЦЕНТРАЛЬ", 4, "Программист", 1150);

select * from GET_JOBS;
select * from GET_JOBS_ALL;

CALL GET_CONTRACTS;

CALL REPORT_PROFS;


CREATE ROLE developer, administrator;


CREATE USER 'dbdeveloper'@'localhost'
  IDENTIFIED BY 'password' DEFAULT ROLE developer;
CREATE USER 'dbadmin'@'localhost'
  IDENTIFIED BY 'password' DEFAULT ROLE administrator;
  
  
CALL CREATE_VACANCY("ООО-ГУПНИИПТЕПЛОЦЕНТРАЛЬ", "Тестировщик", 0, 5000);
