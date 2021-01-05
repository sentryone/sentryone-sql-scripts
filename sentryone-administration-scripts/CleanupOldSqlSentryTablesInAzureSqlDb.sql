/*
Script to cleanup old tables for the SQL Sentry Query and Procedure Stats collection process in an Azure SQL Database.
You can temporarily uncomment the additional columns in the SELECT statement and run the SELECT only to inspect the results before running the full script.
*/

DECLARE @SchemaName NVARCHAR(128) = N'SQLSentry';
DECLARE @BaseTablePattern NVARCHAR(128) = N'QueryStats%';
DECLARE @OldTableName NVARCHAR(128);
DECLARE @MaxAgeHours INT = 72;
DECLARE @DropSqlText NVARCHAR(MAX);

DECLARE OldTables CURSOR FORWARD_ONLY
FOR
	SELECT o.name--, o.create_date, us.last_user_update
	FROM sys.objects o
	LEFT OUTER JOIN sys.dm_db_index_usage_stats us
	  ON o.object_id = us.object_id
	WHERE o.schema_id = SCHEMA_ID(@SchemaName)
	  AND o.type = 'U'
	  AND o.name LIKE @BaseTablePattern
	  AND (us.last_user_update < DATEADD(HOUR, -@MaxAgeHours, GETUTCDATE())
	    OR us.last_user_update IS NULL)
	ORDER BY create_date DESC

OPEN OldTables;
WHILE 1 = 1
BEGIN 
	FETCH OldTables INTO @OldTableName;
	IF @@fetch_status <> 0
		BREAK;

	SET @DropSqlText = N'DROP TABLE ' + @SchemaName + N'.' + @OldTableName;
	EXEC(@DropSqlText);
END
CLOSE OldTables;
DEALLOCATE OldTables;


