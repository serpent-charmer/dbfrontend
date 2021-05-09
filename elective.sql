
drop table if exists elective_minimum;
drop table if exists elective_passed;
drop table if exists elective_stu_link;
drop table if exists elective;
drop table if exists semester;
drop table if exists student;
drop table if exists sgroup;
drop table if exists elective_type;
drop table if exists prof;

create table sgroup (
	id INT,
	gname NVARCHAR(255),
	PRIMARY KEY(id)
);

create table semester (
	id INT,
	sem_period NVARCHAR(9), -- 2019/2020
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
	ehours INT,
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
	FOREIGN KEY(elective_id_ref) references elective(id)
);

create table elective_passed (
	id INT identity,
	elec_link_ref INT,
	grade INT,
	graded_when DATE,
	PRIMARY KEY(id),
	FOREIGN KEY(elec_link_ref) references elective_stu_link(id)
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

	PRINT @etype;
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

SET @sem_period = (select sem_period from Inserted);

DECLARE split_cur CURSOR LOCAL FOR SELECT value from STRING_SPLIT(@sem_period, '/');

OPEN split_cur;

FETCH split_cur INTO @sem_tmp;
SET @sem_bg = CAST(@sem_tmp AS INT);
FETCH split_cur INTO @sem_tmp;
SET @sem_end = CAST(@sem_tmp AS INT);

CLOSE split_cur;
DEALLOCATE split_cur;  

DECLARE @msg VARCHAR(255);
SET @msg = FORMATMESSAGE('Wrong semester period %d %d', @sem_bg, @sem_end);

IF @sem_end - @sem_bg <> 1 
	THROW 60000, @msg, 1;  
END;

GO

CREATE TRIGGER elec_del_check ON elective AFTER DELETE   
AS 
BEGIN 
	DECLARE @eid INT;
	SET @eid = (SELECT id FROM deleted);

	DECLARE @test INT;

	SET @test = (SELECT id from elective_passed where elec_link_ref in (SELECT id from elective_stu_link where elec_id_ref = @eid));
	
	if @test is not null
	THROW 60000, N'Detected unfinished elective', 1;  
	

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
	insert into elective_stu_link (id, elec_id_ref, stu_id_ref) 
	values (@link_id, @stu_id, @elec_id);
END;

GO


create procedure MinimumSatisfied @stu_id INT, @minsat INT OUT AS
BEGIN

if (select abs(count(elective_minimum.id)-(select count(id) from elective_minimum)) 
from elective_minimum right join 
elective_stu_link 
on elective_minimum.id = elective_stu_link.elec_id_ref
and elective_stu_link.stu_id_ref = @stu_id) > 0 
set @minsat = 1;
else
set @minsat = 0;




END;

GO

CREATE PROCEDURE GradeStudentOnElective 
@elec_id INT,
@grade INT, 
@graded_when DATE AS
/*

*/
BEGIN
	-- EXEC MinimumSatisfied @stu_id;
	insert into elective_passed (elec_link_ref, grade, graded_when)
values
(@elec_id, @grade, @graded_when);


END;

GO

create procedure GetGrades 
as begin
	select lf1.grade, lf1.sem_period, lf1.ename, lf1.sname into #tmp_grades from 
((select elective_stu_link.elec_id_ref as elif, 
(select elective.ename from elective where id = elective_stu_link.elec_id_ref) as ename,grade,graded_when, 
(select sem_period from semester where id = 
(select sem_id_ref from elective where id = elective_stu_link.elec_id_ref)) as sem_period,
(select sname from student where id = elective_stu_link.stu_id_ref) as sname,
(select sname from prof where id = (select prof_id_ref from elective where id = elective_stu_link.elec_id_ref)) as prof_name
from 
elective_passed left join elective_stu_link on 
elective_passed.elec_link_ref = elective_stu_link.id) lf1 left join elective on lf1.elif = elective.id) order by lf1.sem_period desc;

	declare @tmp_str NVARCHAR(255);
	declare @tmp_sem NVARCHAR(9);

	declare @tmp_table TABLE(sem_period NVARCHAR(9), ename NVARCHAR(255), grade int, sname NVARCHAR(255));

	declare tmp_cur cursor local for (select distinct ename from #tmp_grades);

	open tmp_cur;
	fetch tmp_cur into @tmp_str;
	while @@FETCH_STATUS = 0
	begin
		set @tmp_sem = (select max(sem_period) from #tmp_grades where ename = @tmp_str);
		insert into @tmp_table values (
		@tmp_sem,
		(@tmp_str),
		(select grade from #tmp_grades where ename = @tmp_str and sem_period = @tmp_sem),
		(select sname from #tmp_grades where ename = @tmp_str and sem_period = @tmp_sem)
		);
		fetch tmp_cur into @tmp_str;
	end;

	close tmp_cur;
	deallocate tmp_cur;

	select * from @tmp_table;

end;

GO

create procedure PassedSemester @stu_id INT as
begin
	declare @minsat INT;
	EXEC MinimumSatisfied @stu_id, @minsat;

	if @minsat = 1 select 'sat';
	else select 'nsat';

end;

GO

drop view if exists elective_view;




GO

CREATE VIEW elective_view AS SELECT id, prof_id_ref, sem_id_ref, ename, ehours, etype from elective;

GO

insert into semester values (2, '2021/2022');
insert into semester values (1, '2020/2021');


insert into sgroup (id, gname) values (1, N'Прикладная математика');
insert into prof (id, sname, phone) values (1, N'Петров Алексей Леонидович', '312312-31231-434');

insert into elective_view values 
(1, 1, 1, N'Технология программирования', 35, N'Практика'),
(3, 1, 2, N'Технология программирования', 35, N'Практика'),
(2, 1, 1, N'Теория чисел', 35, N'Лекции');


insert into student (id, sname, phone, sgroup_ref) 
values 
(1, N'Иванов Петр Иванович', '131231', 1),
(2, N'Петров Иван Алексеввич', '131231', 1);


insert into elective_minimum (id, elective_id_ref) 
values
(1, 1), 
(2, 2);

EXEC EnrollInElective 1, 1, 1;
EXEC EnrollInElective 2, 2, 2;
EXEC EnrollInElective 3, 3, 1;


EXEC GradeStudentOnElective 1, 4, '2019-05-08';
EXEC GradeStudentOnElective 3, 3, '2019-05-08';
EXEC GradeStudentOnElective 2, 5, '2019-03-08';


exec GetGrades;


select elective_passed.elec_link_ref from elective_passed left join (SELECT elective_stu_link.elec_id_ref 
from elective_stu_link where elective_stu_link.stu_id_ref = 1) lf1
on elective_passed.elec_link_ref = lf1.elec_id_ref



EXEC PassedSemester 1;