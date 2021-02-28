
-- VIEW LARGE TEXT COLUMN

	SELECT CAST('<![CDATA[' + sql + ']]>' AS XML) FROM impsql with(nolock) where sql like '%6678%'

-- SP_WHOISACTIVE

	exec sp_whoisactive @show_system_spids = 0,
	@show_sleeping_spids = 1,
	@sort_order = '[login_name],[sql_text] DESC',
	@get_outer_command=1,
	--@filter = 'DB1',
	--@filter_type = 'login',
	@get_task_info = 2


-- CURRENT RUNNING JOBS
	msdb.dbo.sp_help_job @execution_status = 1


-- FIND DEPENDENCIES UPON A TABLE OR COLUMN

	select distinct [Table Name] = o.Name,
	[Found In] = sp.Name,
	sp.type_desc
	from sys.objects o with(nolock)
	inner join sys.sql_expression_dependencies sd with(nolock) on o.object_id = sd.referenced_id
	inner join sys.objects sp with(nolock) on sd.referencing_id = sp.object_id
		and sp.type in ('P', 'FN')
	where o.name = ''
	order by sp.Name


	SELECT c.name AS ColName, t.name AS TableName
	FROM sys.columns c
		JOIN sys.tables t ON c.object_id = t.object_id
	WHERE c.name = '';


	SELECT sys.objects.object_id, sys.schemas.name AS [Schema], sys.objects.name AS Object_Name, sys.objects.type_desc AS [Type]
	FROM sys.sql_modules (NOLOCK)
	INNER JOIN sys.objects (NOLOCK) ON sys.sql_modules.object_id = sys.objects.object_id
	INNER JOIN sys.schemas (NOLOCK) ON sys.objects.schema_id = sys.schemas.schema_id
	WHERE
		sys.sql_modules.definition COLLATE SQL_Latin1_General_CP1_CI_AS LIKE '%departmentName%' --ESCAPE '\'
	ORDER BY sys.objects.type_desc, sys.schemas.name, sys.objects.name


-- MISSING DEPENDENCIES

	select o.type, o.name, ed.referenced_entity_name, ed.is_caller_dependent
	from sys.sql_expression_dependencies ed
	join sys.objects o on ed.referencing_id = o.object_id
	where ed.referenced_id is null
	order by o.name


	select o.type, o.name, ed.referenced_entity_name, ed.is_caller_dependent
	from sys.sql_expression_dependencies ed
	join sys.objects o on ed.referencing_id = o.object_id
	where ed.referenced_id is null
	and (o.name not like '%connection%' and o.name not like '%_deleted%') and (ed.referenced_entity_name like '%sso%' or ed.referenced_entity_name like '%web%')
	order by o.name



-- JOB AND JOBSTEP INFO

	SELECT JOB.NAME AS JOB_NAME,
	STEP.STEP_ID AS STEP_NUMBER,
	STEP.STEP_NAME AS STEP_NAME,
	STEP.COMMAND AS STEP_QUERY,
	DATABASE_NAME,
	*
	FROM Msdb.dbo.SysJobs JOB
	INNER JOIN Msdb.dbo.SysJobSteps STEP ON STEP.Job_Id = JOB.Job_Id
	WHERE JOB.Enabled = 1
	AND (JOB.Name = 'Imp Commit Stage' )
	ORDER BY JOB.NAME, STEP.STEP_ID


-- OPEN CONNECTION TO OTHER SERVER

	insert into t1(col1, col2)
	SELECT col1, col2
	FROM OPENDATASOURCE('SQLNCLI',
		'Data Source=blah.server.net;Initial Catalog=blah;User ID=id;Password=pw')
		.blah.dbo.t1

-- FIND AND REPLACE TEXT IN PROCS/VIEWS/FUNCTIONS

	select object_definition(id) as original,
		replace(object_definition(id),'replacethis', 'withthis') as updated
		,*
	from sys.sysobjects o
	where object_definition(id) like '%replacethis%'
	and xtype in ('p')


-- INSERT SP_WHOISACTIVE RESULTS TO TEMP TABLE

    declare @whoisactive_table varchar(4000) = quotename('spWhoIsActive_' + cast(newid() as varchar(255)))
    declare @schema varchar(4000)
    declare @sql nvarchar(4000)
    declare @filterToMyHostNameYN bit = 1
    declare @myHostName varchar(100) = 'WA800689X-CHC'

    exec sp_WhoIsActive @output_column_list = '[tempdb%][%]', @get_plans = 1, @return_schema = 1, @format_output = 0, @schema = @schema output
    set @schema = replace(@schema, '<table_name>', @whoisactive_table)
    exec (@schema)
    exec sp_WhoIsActive @output_column_list = '[tempdb%][%]', @get_plans = 1, @format_output = 0, @destination_table = @whoisactive_table

    set @sql = N'select * from ' + @whoisactive_table + N' where host_name = @myHostName or @filterToMyHostNameYN = 0 '
    set @sql += N'drop table ' + @whoisactive_table

    exec sys.sp_executesql @sql, N'@filterToMyHostNameYN bit, @myHostName varchar(100)', @filterToMyHostNameYN = @filterToMyHostNameYN, @myHostName = @myHostName