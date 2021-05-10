drop table if exists last_grade;
drop table if exists elective_minimum;
drop table if exists elective_passed;
drop table if exists elective_stu_link;
drop table if exists elective;
drop table if exists semester;
drop table if exists student;
drop table if exists sgroup;
drop table if exists prof;

create table sgroup (
	id INT,
	gname NVARCHAR(255),
	PRIMARY KEY(id)
);

create table semester (
	id INT,
	sem_period NVARCHAR(32), -- 2019/2020
	PRIMARY KEY(id),
);

create table student ( 
	id INT,
	sname NVARCHAR(255),
	phone NVARCHAR(255),
	sgroup_ref INT,
	PRIMARY KEY (id),
	FOREIGN KEY(sgroup_ref) references sgroup(id)
);

create table prof ( 
	id INT,
	sname NVARCHAR(255),
	phone NVARCHAR(255),
	PRIMARY KEY (id)
);

create table elective (
	id INT,
	ename NVARCHAR(255),
	ehours INT CHECK (ehours > 30),
	etype NVARCHAR(255),
	prof_id_ref INT NOT NULL,
	sem_id_ref INT,
	PRIMARY KEY(id),
	FOREIGN KEY(prof_id_ref) REFERENCES prof(id),
	FOREIGN KEY(sem_id_ref) references semester(id)
);

create table elective_stu_link (
	id INT,
	elec_id_ref INT,
	stu_id_ref INT,
	PRIMARY KEY(id),
	FOREIGN KEY(elec_id_ref) references elective(id),
	FOREIGN KEY(stu_id_ref) references student(id)
);

create table elective_minimum (
	id INT,
	elective_id_ref INT,
	sem_id_ref INT,
	FOREIGN KEY(elective_id_ref) references elective(id),
	FOREIGN KEY(sem_id_ref) references semester(id)
);

create table elective_passed (
	id INT identity,
	elec_link_ref INT unique,
	grade INT,
	PRIMARY KEY(id),
	FOREIGN KEY(elec_link_ref) references elective_stu_link(id),
	CONSTRAINT grade_logic CHECK (grade > 0 and grade <= 5)
);

create table last_grade (
	elec_passed_id INT,
	elec_name_ref NVARCHAR(255),
	stu_id_ref INT,
	primary key (elec_name_ref, stu_id_ref),
	foreign key(stu_id_ref) references student(id)
);

GO

CREATE TRIGGER elec_type_check ON elective AFTER INSERT   
AS 
BEGIN
	DECLARE @etype NVARCHAR(255);
	DECLARE @rs INT;
	DECLARE etype_cur CURSOR LOCAL FOR (SELECT etype from inserted);
	OPEN etype_cur;

	fetch etype_cur into @etype;

	WHILE @@FETCH_STATUS = 0  
	begin
		if @etype = N'Лекции' SET @rs = 1;
		if @etype = N'Практика' SET @rs = 1;
		if @etype = N'Лабораторные работы' SET @rs = 1;
		fetch etype_cur into @etype;
	end;

	close etype_cur;

	if @rs is null THROW 60000, 'Unknown elective type', 1;  
	
END;

GO

CREATE TRIGGER sem_check_period ON semester AFTER INSERT, UPDATE   
AS 
BEGIN 
DECLARE @sem_period NVARCHAR(16);
DECLARE @sem_tmp NVARCHAR(16);
DECLARE @sem_bg INT;
DECLARE @sem_end INT;
DECLARE @sem_season NVARCHAR(16);

SET @sem_period = (select sem_period from Inserted);

DECLARE split_cur CURSOR LOCAL FOR SELECT value from STRING_SPLIT(@sem_period, '/');

OPEN split_cur;

FETCH split_cur INTO @sem_tmp;
SET @sem_bg = CAST(@sem_tmp AS INT);
FETCH split_cur INTO @sem_tmp;
SET @sem_end = CAST(@sem_tmp AS INT);
FETCH split_cur INTO @sem_tmp;
SET @sem_season = CAST(@sem_tmp AS NVARCHAR(32));

CLOSE split_cur;
DEALLOCATE split_cur;  

DECLARE @msg VARCHAR(255);
SET @msg = FORMATMESSAGE('Wrong semester period %d %d', @sem_bg, @sem_end);

IF @sem_end - @sem_bg <> 1 and (@sem_season <> N'осень' or @sem_season <> N'весна')
	THROW 60000, @msg, 1;  
END;

GO

CREATE TRIGGER elec_del_check ON elective AFTER DELETE   
AS 
BEGIN 
	SELECT '';
	THROW 60000, N'Err', 1;  
END;

GO

DROP PROCEDURE IF EXISTS MinimumSatisfied; 
DROP PROCEDURE IF EXISTS GradeStudentOnElective;
DROP PROCEDURE IF EXISTS EnrollInElective;
DROP PROCEDURE IF EXISTS GetGrades;

GO

CREATE PROCEDURE EnrollInElective
@link_id INT,
@stu_id INT, 
@elec_id INT
AS BEGIN
	insert into elective_stu_link (id, stu_id_ref, elec_id_ref) 
	values (@link_id, @stu_id, @elec_id);
END;

GO


create procedure MinimumSatisfied @stu_id INT, @sem_id INT as
BEGIN

if (select abs(count(elective_minimum.id)-(select count(id) from elective_minimum)) 
from elective_minimum right join 
elective_stu_link 
on elective_minimum.id = elective_stu_link.elec_id_ref
and elective_stu_link.stu_id_ref = @stu_id and elective_minimum.sem_id_ref = @sem_id) = 0
select N'Выполнен' as N'Минимум';
else select N'Не выполнен' as N'Минимум';




END;

GO

CREATE PROCEDURE GradeStudentOnElective 
@elec_id INT,
@grade INT 
AS
BEGIN
	-- EXEC MinimumSatisfied @stu_id;
	
	insert into elective_passed (elec_link_ref, grade)
values
(@elec_id, @grade);
begin try 
		insert into last_grade (elec_passed_id, elec_name_ref, stu_id_ref) 
		values
		(@elec_id, 
		(select ename from elective where id = (select elective_stu_link.elec_id_ref from elective_stu_link where id = @elec_id)),
		(select elective_stu_link.stu_id_ref from elective_stu_link where id = @elec_id));
	end try
	begin catch
		update last_grade set 
		elec_passed_id = @elec_id 
			where 
			elec_name_ref = (select ename from elective where id = (select elective_stu_link.elec_id_ref from elective_stu_link where id = @elec_id))
			and
			stu_id_ref = (select elective_stu_link.stu_id_ref from elective_stu_link where id = @elec_id);
	end catch;

END;

GO

create procedure GetGrades 
as begin
SELECT        sgroup.gname, student.sname, prof.sname AS prof_name, elective_passed.grade, elective.ename, elective.ehours, semester.sem_period
FROM            last_grade INNER JOIN
                         elective_stu_link ON last_grade.stu_id_ref = elective_stu_link.stu_id_ref INNER JOIN
                         elective ON elective_stu_link.elec_id_ref = elective.id INNER JOIN
                         prof ON elective.prof_id_ref = prof.id INNER JOIN
                         student ON elective_stu_link.stu_id_ref = student.id INNER JOIN
                         elective_passed ON last_grade.elec_passed_id = elective_passed.id AND elective_stu_link.id = elective_passed.elec_link_ref INNER JOIN
                         semester ON elective.sem_id_ref = semester.id INNER JOIN
                         sgroup ON student.sgroup_ref = sgroup.id
						 end;

GO




GO

drop procedure if exists CreateSemester;

GO

create procedure CreateSemester @sem_id INT, @sem_period NVARCHAR(32) as 
begin
	begin try
		begin tran
		insert into semester values (@sem_id, @sem_period);
		commit tran
	end try
	begin catch
		IF @@TRANCOUNT > 0
		begin
			ROLLBACK TRAN;
			PRINT 'ROLLED BACK';
		end;
	end catch;
end;

GO

drop view if exists elective_view;
drop view if exists student_view;



GO

CREATE VIEW elective_view AS SELECT id, prof_id_ref, sem_id_ref, ename, ehours, etype from elective;

GO

create view student_view as select id, sname, phone, sgroup_ref from student

GO

EXEC CreateSemester 1, N'2021/2022/осень';
EXEC CreateSemester 2, N'2022/2023/весна';




insert into sgroup (id, gname) values 
(1, N'Прикладная математика'),
(2, N'Прикладная информатика');
insert into prof (id, sname, phone) values (1, N'Петров Алексей Леонидович', '312312-31231-434');

insert into student_view 
values 
(1, N'Иванов Петр Иванович', '131231', 1),
(2, N'Петров Иван Алексеввич', '131231', 2);




insert into elective_view values 
(1, 1, 1, N'Технология программирования', 35, N'Практика'),
(2, 1, 1, N'Теория чисел', 35, N'Лекции'),
(3, 1, 2, N'Технология программирования', 35, N'Практика'),
(4, 1, 2, N'Дифференциальные уравнения в экономике', 45, N'Лабораторные работы');

EXEC EnrollInElective 1, 1, 1;
EXEC EnrollInElective 2, 2, 2;
EXEC EnrollInElective 3, 1, 3;

EXEC EnrollInElective 4, 1, 2;


EXEC GradeStudentOnElective 1, 3;
EXEC GradeStudentOnElective 2, 5;
EXEC GradeStudentOnElective 3, 2;


insert into elective_minimum (id, elective_id_ref, sem_id_ref) 
values
(1, 1, 1), 
(2, 2, 1);

exec GetGrades;

exec MinimumSatisfied 1, 1; 


GO
/*
exec CreateSemester 3, N'2022/2023осень'; -- rollback 

insert into elective_view values 
(6, 1, 2, N'Вычислительная теория групп', 15, N'Лекции'); -- ehours constraint

EXEC EnrollInElective 4, 1, 3;
EXEC GradeStudentOnElective 2, -1, '2019-03-08'; -- grade_logic constraint
*/