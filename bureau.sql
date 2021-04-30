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
			FOREIGN KEY(ref_employer) REFERENCES employer (id)
) CHARACTER SET utf8mb4;

CREATE TABLE contract (
			id INT(11) AUTO_INCREMENT,
            ref_employer INT(11) NOT NULL,
            ref_employee INT(11) NOT NULL,
            ref_vacancy INT(11) NOT NULL,
            comissions INT(11) NOT NULL CHECK(comissions > 100),
            payed BOOL DEFAULT FALSE,
            PRIMARY KEY(id),
            FOREIGN KEY(ref_employer) REFERENCES employer(id),
            FOREIGN KEY(ref_employee) REFERENCES employee (id),
            FOREIGN KEY(ref_vacancy) REFERENCES vacancy (id)
        ) CHARACTER SET utf8mb4;
        

        

            
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
				SET vid = (select id from vacancy where ref_employer = (select id from employer where name = employer_name) and job_desc = profession);
         if(vid IS NOT NULL) then
            INSERT INTO contract (ref_employer, ref_employee, ref_vacancy, comissions) 
			 VALUES(
             (select id from employer where name = employer_name),
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
         DECLARE eid INT DEFAULT NULL;
         SET eid = (select id from employer where name = employer_name);
		 INSERT INTO vacancy (job_desc, experience, ref_employer, salary) VALUES(job_desc, experience, eid, salary);
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

DROP VIEW IF EXISTS GET_JOBS;
CREATE VIEW GET_JOBS AS SELECT job_desc, name, experience, salary from vacancy left join employer on vacancy.ref_employer = employer.id;

DROP VIEW IF EXISTS EMPLOYER_VIEW;
CREATE VIEW EMPLOYER_VIEW AS SELECT employer.name, employer.address, employer.phone_number from employer;

DROP VIEW IF EXISTS EMPLOYEE_VIEW;
CREATE VIEW EMPLOYEE_VIEW AS SELECT employee.name, surname, third_name, profession, email from employee;



DROP procedure IF EXISTS GET_CONTRACTS;
DELIMITER //
CREATE PROCEDURE GET_CONTRACTS()
       BEGIN
         SELECT vacancy.job_desc as hired, lf2.id, lf2.ename, lf2.name, lf2.surname, lf2.third_name, lf2.payed, lf2.comissions FROM (SELECT lf1.ref_vacancy,lf1.id,ename,name,surname,third_name,payed,comissions FROM 
			 (SELECT contract.id,ref_vacancy, comissions, name as ename, payed, ref_employee from contract 
			 left join employer on contract.ref_employer = employer.id) lf1 
         left join employee on lf1.ref_employee = employee.id) lf2 left join vacancy on lf2.ref_vacancy = vacancy.id;
       END//
DELIMITER ;

DROP procedure IF EXISTS PAY_CONTRACT;
DELIMITER //
CREATE PROCEDURE PAY_CONTRACT()
       BEGIN
         SELECT hired,ename,name,surname,third_name,payed,comissions FROM (SELECT comissions, profession as hired, name as ename, payed, ref_employee from contract left join employer on contract.ref_employer = employer.id) lf1 left join employee on lf1.ref_employee = employee.id;
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
CREATE TRIGGER upd_check BEFORE INSERT ON vacancy
       FOR EACH ROW
       BEGIN
            if(NEW.experience >= 2 and NEW.salary <= 15000) then
				SET @s = CONCAT('Для опыта работы больше двух лет минимальная з/р 15т.');
				SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @s;
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
CALL CREATE_VACANCY("ООО-ГУПНИИПТЕПЛОЦЕНТРАЛЬ", "Ассистент", 0, 5000);
CALL CREATE_CONTRACT("ООО-ГУПНИИПТЕПЛОЦЕНТРАЛЬ", 1, "ФинТех Аналитик", 150);
SELECT * from contract;
delete from contract;
select * from vacancy;
select * from GET_JOBS;

CALL REPORT_PROFS;

