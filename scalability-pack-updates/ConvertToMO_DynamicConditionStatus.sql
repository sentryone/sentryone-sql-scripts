/*** Script to convert DynamicConditionStatus table from disk-based to memory-optimized to reduce contention and chance of deadlocks on busy systems ***

FIRST:
	"Snooze All For->1 Hour" from Configuration->Advisory Conditions node. (ACs will still log, but will not do any work)
	ACs will be un-snoozed automatically by the script.

NOTE:
	Hash index BUCKET_COUNTs should be adjusted up from 4096 if needed.
	Set to 1.2 * the max rows expected in DynamicConditionStatus, rounded up to the next power of 2 (4096->8192->16384->32768).
		SELECT COUNT(1) FROM DynamicConditionStatus;
	I don't recommend lowering below 4096 even if they are much lower, to allow room for growth. Better too high than too low.
	See: https://msdn.microsoft.com/en-us/library/dn494956(v=sql.120).aspx

IMPORTANT:
	Key violation errors can sometimes occur when the data is moved into the new mem-opt table due to a bug in SQL Server. These errors are benign and can be ignored.

DISCLAIMER:
	These updates are considered preview, and should be used at your own risk.

Copyright 2020 SQL Sentry, LLC
*/

USE [SentryOne];
GO

/*** Only execute this section if the system hasn't already had the Scalability Pack (CCI + In-Mem) installed ***
 *** System Requirements are the same as the Scalability Pack ***

ALTER DATABASE [SentryOne] SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT = ON --will ensure procs won't break if RCSI is ever enabled.
GO

--You will get an error if the following attempts to execute against master.
--Create mem-optimized filegroup in the default data dir.
ALTER DATABASE CURRENT ADD FILEGROUP [MemOptFG] CONTAINS MEMORY_OPTIMIZED_DATA
GO

DECLARE @sql nvarchar(max) =
	N'ALTER DATABASE CURRENT
		ADD FILE (name=''MemOptData'', filename=' +
		QUOTENAME(cast(SERVERPROPERTY('InstanceDefaultDataPath') as nvarchar(max)) + db_name() + N'_MemOptData', N'''') +
		') TO FILEGROUP [MemOptFG]'
select @sql;
EXECUTE sp_executesql @sql;
GO
*/

--First ensure that the table hasn't already been converted to memory-optimized:
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'DynamicConditionStatus' AND is_memory_optimized = 1)
  BEGIN
	RAISERROR('DynamicConditionStatus already converted to memory-optimized!', 11, 1);
	SET NOEXEC ON; --ensure rest of script will not execute.
  END
GO

--Kneecap existing procs so data won't be inserted by services while existing data is being moved into the new in-mem table,
--which will cause key violations. New natively compiled procs will be created below, after insert has completed.
ALTER PROCEDURE [dbo].[LogDynamicConditionStatusStart]
	@ConditionID UNIQUEIDENTIFIER,
	@DynamicConditionID INT,
	@ObjectID UNIQUEIDENTIFIER,
	@CurrentEvaluationStartTimeUtc DATETIME,
	@CurrentEvaluationType TINYINT
AS
	RETURN;
GO

ALTER PROCEDURE [dbo].[LogDynamicConditionStatusEnd]
	@ConditionID UNIQUEIDENTIFIER,
	@DynamicConditionID INT,
	@ObjectID UNIQUEIDENTIFIER,
	@LastEvaluationStartTimeUtc DATETIME,
	@LastEvaluationEndTimeUtc DATETIME,
	@LastEvaluationDuratioUnTicks BIGINT,
	@LastEvaluationResults NVARCHAR(MAX),
	@LastEvaluationState TINYINT,
	@DynamicConditionEvaluationResult TINYINT,
	@LastEvaluationException NVARCHAR(MAX)
AS
	RETURN;
GO

EXEC sp_rename 'dbo.DynamicConditionStatus', 'DynamicConditionStatus_bak';
GO

SET ANSI_NULLS ON
GO

CREATE TABLE [dbo].[DynamicConditionStatus]
(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ConditionID] [uniqueidentifier] NOT NULL,
	[DynamicConditionID] [int] NOT NULL,
	[ObjectID] [uniqueidentifier] NOT NULL,
	[CurrentEvaluationStartTimeUtc] [datetime] NULL,
	[LastEvaluationStartTimeUtc] [datetime] NULL,
	[LastEvaluationEndTimeUtc] [datetime] NULL,
	[LastEvaluationDurationTicks] [bigint] NULL,
	[LastEvaluationResults] [nvarchar](max) NULL,
	[LastEvaluationState] [tinyint] NULL,
	[LastEvaluationException] [nvarchar](max) NULL,
	[DynamicConditionEvaluationResult] [tinyint] NULL,
	[CurrentEvaluationType] [tinyint] NULL,
	CONSTRAINT [PK_DynamicConditionStatus] PRIMARY KEY NONCLUSTERED HASH ([ID]) WITH (BUCKET_COUNT = 4096)
) WITH ( MEMORY_OPTIMIZED = ON , DURABILITY = SCHEMA_ONLY )
GO

ALTER TABLE [DynamicConditionStatus]  
    ADD INDEX [IX_LastEvaluationStartTimeUtc_ID]
    NONCLUSTERED (LastEvaluationStartTimeUtc ASC, ID ASC);  
GO 

ALTER TABLE [DynamicConditionStatus]  
    ADD CONSTRAINT [IX_Unique]
    UNIQUE NONCLUSTERED HASH (ConditionID, ObjectID) WITH (BUCKET_COUNT = 4096);
GO

SET IDENTITY_INSERT [DynamicConditionStatus] ON
GO

INSERT INTO [dbo].[DynamicConditionStatus]
	(
	 [ID]
	,[ConditionID]
	,[DynamicConditionID]
	,[ObjectID]
	,[CurrentEvaluationStartTimeUtc]
	,[LastEvaluationStartTimeUtc]
	,[LastEvaluationEndTimeUtc]
	,[LastEvaluationDurationTicks]
	,[LastEvaluationResults]
	,[LastEvaluationState]
	,[LastEvaluationException]
	,[DynamicConditionEvaluationResult]
	,[CurrentEvaluationType]
	)
SELECT [ID]
      ,[ConditionID]
      ,[DynamicConditionID]
      ,[ObjectID]
      ,[CurrentEvaluationStartTimeUtc]
      ,[LastEvaluationStartTimeUtc]
      ,[LastEvaluationEndTimeUtc]
      ,[LastEvaluationDurationTicks]
      ,[LastEvaluationResults]
      ,[LastEvaluationState]
      ,[LastEvaluationException]
      ,[DynamicConditionEvaluationResult]
      ,[CurrentEvaluationType]
  FROM [dbo].[DynamicConditionStatus_bak]
GO

SET IDENTITY_INSERT [DynamicConditionStatus] OFF
GO

DROP PROC IF EXISTS [dbo].[LogDynamicConditionStatusStart]
GO

CREATE PROCEDURE [dbo].[LogDynamicConditionStatusStart]
	@ConditionID UNIQUEIDENTIFIER,
	@DynamicConditionID INT,
	@ObjectID UNIQUEIDENTIFIER,
	@CurrentEvaluationStartTimeUtc DATETIME,
	@CurrentEvaluationType TINYINT
WITH NATIVE_COMPILATION, SCHEMABINDING  
AS
BEGIN ATOMIC WITH   
(  
	TRANSACTION ISOLATION LEVEL = SNAPSHOT,  
	LANGUAGE = N'us_english'  
)
	UPDATE dbo.DynamicConditionStatus 
	SET
		DynamicConditionID = @DynamicConditionID, 
		CurrentEvaluationStartTimeUtc = @CurrentEvaluationStartTimeUtc,
		CurrentEvaluationType = @CurrentEvaluationType
	WHERE ConditionID = @ConditionID AND ObjectID = @ObjectID
	IF @@ROWCOUNT = 0
	BEGIN
		INSERT INTO dbo.DynamicConditionStatus 
		(
			dbo.DynamicConditionStatus.ConditionID, 
			dbo.DynamicConditionStatus.DynamicConditionID, 
			dbo.DynamicConditionStatus.ObjectID, 
			dbo.DynamicConditionStatus.CurrentEvaluationStartTimeUtc,
			dbo.DynamicConditionStatus.CurrentEvaluationType
		) 
		VALUES 
		(
			@ConditionID, 
			@DynamicConditionID, 
			@ObjectID, 
			@CurrentEvaluationStartTimeUtc,
			@CurrentEvaluationType
		)
	END

END;
GO

DROP PROC IF EXISTS [dbo].[LogDynamicConditionStatusEnd]
GO

CREATE PROCEDURE [dbo].[LogDynamicConditionStatusEnd]
	@ConditionID UNIQUEIDENTIFIER,
	@DynamicConditionID INT,
	@ObjectID UNIQUEIDENTIFIER,
	@LastEvaluationStartTimeUtc DATETIME,
	@LastEvaluationEndTimeUtc DATETIME,
	@LastEvaluationDurationTicks BIGINT,
	@LastEvaluationResults NVARCHAR(MAX),
	@LastEvaluationState TINYINT,
	@DynamicConditionEvaluationResult TINYINT,
	@LastEvaluationException NVARCHAR(MAX)
WITH NATIVE_COMPILATION, SCHEMABINDING  
AS
BEGIN ATOMIC WITH   
(  
	TRANSACTION ISOLATION LEVEL = SNAPSHOT,  
	LANGUAGE = N'us_english'  
)
	DECLARE @ID int;
	SET @ID =
		(
		SELECT MAX(ID)
		FROM dbo.DynamicConditionStatus
		WHERE ConditionID = @ConditionID
		  AND ObjectID = @ObjectID 
		);

	IF (@ID IS NOT NULL)
		UPDATE dbo.DynamicConditionStatus 
		SET
			DynamicConditionID = @DynamicConditionID, 
			LastEvaluationStartTimeUtc = @LastEvaluationStartTimeUtc,
			LastEvaluationEndTimeUtc = @LastEvaluationEndTimeUtc,
			LastEvaluationDurationTicks = @LastEvaluationDurationTicks,
			LastEvaluationResults = @LastEvaluationResults,
			LastEvaluationState = @LastEvaluationState,
			DynamicConditionEvaluationResult = @DynamicConditionEvaluationResult,
			LastEvaluationException = @LastEvaluationException
		WHERE ID = @ID;
	ELSE
		INSERT INTO dbo.DynamicConditionStatus 
		(
			dbo.DynamicConditionStatus.ConditionID, 
			dbo.DynamicConditionStatus.DynamicConditionID, 
			dbo.DynamicConditionStatus.ObjectID, 
			dbo.DynamicConditionStatus.LastEvaluationStartTimeUtc,
			dbo.DynamicConditionStatus.LastEvaluationEndTimeUtc,
			dbo.DynamicConditionStatus.LastEvaluationDurationTicks,
			dbo.DynamicConditionStatus.LastEvaluationResults,
			dbo.DynamicConditionStatus.LastEvaluationState,
			dbo.DynamicConditionStatus.DynamicConditionEvaluationResult,
			dbo.DynamicConditionStatus.LastEvaluationException
		) 
		VALUES 
		(
			@ConditionID, 
			@DynamicConditionID, 
			@ObjectID, 
			@LastEvaluationStartTimeUtc,
			@LastEvaluationEndTimeUtc,
			@LastEvaluationDurationTicks,
			@LastEvaluationResults,
			@LastEvaluationState,
			@DynamicConditionEvaluationResult,
			@LastEvaluationException
		);

END;
GO

--Remove DELETE for DCS to prevent isolation level errors upon AC deletion.
ALTER TRIGGER [dbo].[trgAfterDynamicConditionDefinition_Delete]
   ON  [dbo].[DynamicConditionDefinition]
   AFTER DELETE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF NOT EXISTS
	(
		SELECT dbo.DynamicConditionDefinition.ID
		FROM dbo.DynamicConditionDefinition
		INNER JOIN deleted ON dbo.DynamicConditionDefinition.ConditionID = deleted.ConditionID
	)
	BEGIN
		DELETE dbo.ObjectConditionAction
		FROM dbo.ObjectConditionAction
		INNER JOIN deleted ON dbo.ObjectConditionAction.ConditionTypeID = deleted.ConditionID

		DELETE dbo.SnoozeStatus
		FROM dbo.SnoozeStatus
		INNER JOIN deleted ON dbo.SnoozeStatus.ConditionID = deleted.ConditionID

		DELETE dbo.DynamicConditionDefinitionRefreshRequest
		FROM dbo.DynamicConditionDefinitionRefreshRequest
		INNER JOIN deleted ON dbo.DynamicConditionDefinitionRefreshRequest.ConditionID = deleted.ConditionID

		DELETE dbo.DynamicConditionDefinitionArea
		FROM dbo.DynamicConditionDefinitionArea
		INNER JOIN deleted ON dbo.DynamicConditionDefinitionArea.ConditionID = deleted.ConditionID
	END
END
GO

--Recompile dependent objects
exec sp_recompile 'dbo.LogDynamicConditionStatusStart';
GO
exec sp_recompile 'dbo.LogDynamicConditionStatusEnd';
GO
exec sp_recompile 'dbo.GetDynamicConditionStatuses';
GO
exec sp_recompile 'dbo.GetDynamicConditionResultsForDefinitionAndObject';
GO
exec sp_recompile 'dbo.PurgeDataBeforeDateTime';
GO
exec sp_recompile 'dbo.trgAfterDynamicConditionDefinition_Delete';
GO

--Clear associated snooze rows
DELETE
FROM SnoozeStatus
--select * from SnoozeStatus
WHERE ConditionID IS NOT NULL
  AND SnoozeStartTimeUtc > DATEADD(MINUTE, -5, GETUTCDATE());
GO


/* Roll Back Mem-Opt conversion:
USE SentryOne
GO

DROP PROCEDURE [dbo].[LogDynamicConditionStatusEnd]
GO

DROP PROCEDURE [dbo].[LogDynamicConditionStatusStart]
GO

DROP TABLE DynamicConditionStatus --*** THE MEM-OPT TABLE ONLY -- DO NOT DROP THE ORIGINAL DISK-BASED TABLE ***
GO

EXEC sp_rename 'dbo.DynamicConditionStatus_bak', 'DynamicConditionStatus';
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--*** IF THE 2 PROCS BELOW HAVE CHANGED, USE THE NEW VERSIONS INSTEAD ***

CREATE PROCEDURE [dbo].[LogDynamicConditionStatusStart]
	@ConditionID UNIQUEIDENTIFIER,
	@DynamicConditionID INT,
	@ObjectID UNIQUEIDENTIFIER,
	@CurrentEvaluationStartTimeUtc DATETIME,
	@CurrentEvaluationType TINYINT
AS

SET NOCOUNT ON
BEGIN TRANSACTION
UPDATE dbo.DynamicConditionStatus 
SET
	DynamicConditionID = @DynamicConditionID, 
	CurrentEvaluationStartTimeUtc = @CurrentEvaluationStartTimeUtc,
	CurrentEvaluationType = @CurrentEvaluationType
WHERE ConditionID = @ConditionID AND ObjectID = @ObjectID
IF @@ROWCOUNT = 0
BEGIN
	INSERT INTO dbo.DynamicConditionStatus 
	(
		dbo.DynamicConditionStatus.ConditionID, 
		dbo.DynamicConditionStatus.DynamicConditionID, 
		dbo.DynamicConditionStatus.ObjectID, 
		dbo.DynamicConditionStatus.CurrentEvaluationStartTimeUtc,
		dbo.DynamicConditionStatus.CurrentEvaluationType
	) 
	VALUES 
	(
		@ConditionID, 
		@DynamicConditionID, 
		@ObjectID, 
		@CurrentEvaluationStartTimeUtc,
		@CurrentEvaluationType
	)
END
COMMIT TRANSACTION
GO

CREATE PROCEDURE [dbo].[LogDynamicConditionStatusEnd]
	@ConditionID UNIQUEIDENTIFIER,
	@DynamicConditionID INT,
	@ObjectID UNIQUEIDENTIFIER,
	@LastEvaluationStartTimeUtc DATETIME,
	@LastEvaluationEndTimeUtc DATETIME,
	@LastEvaluationDurationTicks BIGINT,
	@LastEvaluationResults NVARCHAR(MAX),
	@LastEvaluationState TINYINT,
	@DynamicConditionEvaluationResult TINYINT,
	@LastEvaluationException NVARCHAR(MAX)
AS

SET NOCOUNT ON
BEGIN TRANSACTION

DECLARE @ID int
SET @ID =
	(
	SELECT ID
	FROM dbo.DynamicConditionStatus
	WHERE ConditionID = @ConditionID
	  AND ObjectID = @ObjectID 
	);

IF (@ID IS NOT NULL)
	UPDATE dbo.DynamicConditionStatus 
	SET
		DynamicConditionID = @DynamicConditionID, 
		LastEvaluationStartTimeUtc = @LastEvaluationStartTimeUtc,
		LastEvaluationEndTimeUtc = @LastEvaluationEndTimeUtc,
		LastEvaluationDurationTicks = @LastEvaluationDurationTicks,
		LastEvaluationResults = @LastEvaluationResults,
		LastEvaluationState = @LastEvaluationState,
		DynamicConditionEvaluationResult = @DynamicConditionEvaluationResult,
		LastEvaluationException = @LastEvaluationException
	WHERE ID = @ID
ELSE
	INSERT INTO dbo.DynamicConditionStatus 
	(
		dbo.DynamicConditionStatus.ConditionID, 
		dbo.DynamicConditionStatus.DynamicConditionID, 
		dbo.DynamicConditionStatus.ObjectID, 
		dbo.DynamicConditionStatus.LastEvaluationStartTimeUtc,
		dbo.DynamicConditionStatus.LastEvaluationEndTimeUtc,
		dbo.DynamicConditionStatus.LastEvaluationDurationTicks,
		dbo.DynamicConditionStatus.LastEvaluationResults,
		dbo.DynamicConditionStatus.LastEvaluationState,
		dbo.DynamicConditionStatus.DynamicConditionEvaluationResult,
		dbo.DynamicConditionStatus.LastEvaluationException
	) 
	VALUES 
	(
		@ConditionID, 
		@DynamicConditionID, 
		@ObjectID, 
		@LastEvaluationStartTimeUtc,
		@LastEvaluationEndTimeUtc,
		@LastEvaluationDurationTicks,
		@LastEvaluationResults,
		@LastEvaluationState,
		@DynamicConditionEvaluationResult,
		@LastEvaluationException
	)

COMMIT TRANSACTION
GO
*/

/* Get Dependent Objects for Recompile:
SELECT DISTINCT
	'exec sp_recompile ''' + OBJECT_SCHEMA_NAME(referencing_id) + '.' + OBJECT_NAME(referencing_id) + ''';'
	--,*
FROM sys.sql_expression_dependencies AS sed  
INNER JOIN sys.objects AS o
   ON sed.referencing_id = o.object_id
WHERE referenced_id = OBJECT_ID(N'DynamicConditionStatus')
  AND referenced_minor_id = 0; 
*/
