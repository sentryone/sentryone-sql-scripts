/*** Script to enable Advisory Condition Evaluation Tracking ***

IMPORTANT: SentryOne database MUST have a memory-optimized filegroup and the DynamicConditionStatus table MUST be memory-optimized.

DISCLAIMER: These updates are considered preview, and should be used at your own risk.

Copyright 2020 SQL Sentry, LLC
*/

USE [SentryOne];

DROP TRIGGER IF EXISTS [dbo].[trgLogACEvaluationResults];
GO
DROP TABLE IF EXISTS [dbo].[DynamicConditionEvaluationTracking];
GO
DROP TABLE IF EXISTS [dbo].[DynamicConditionEvaluationValueTypes];
GO
DROP TABLE IF EXISTS [dbo].[DynamicConditionEvaluationObjectTypePerformanceCategory];
GO
DROP TABLE IF EXISTS [Staging].[MO_DynamicConditionEvaluationResults];
GO
DROP PROC IF EXISTS [dbo].[SetAdvisoryConditionEvaluationTracking];
GO
DELETE PerformanceAnalysisCounter WHERE PerformanceAnalysisCounterCategoryID BETWEEN 1000 AND 1020;
GO
DELETE PerformanceAnalysisCounterCategory WHERE ID BETWEEN 1000 AND 1020;
GO

CREATE TABLE [dbo].[DynamicConditionEvaluationTracking]
(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ConditionID] [uniqueidentifier] NOT NULL,
	[DynamicConditionID] [int] NOT NULL,
	[UniqueKey] [nvarchar](4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ObjectID] [uniqueidentifier] NULL,
	[CounterID] [smallint] NOT NULL,
	[Enabled] [bit] NOT NULL,
	[CreatedByUser] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DateCreatedUTC] [datetime] NULL,
	[UpdatedByUser] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DateUpdatedUTC] [datetime] NULL,
	CONSTRAINT [PK_DynamicConditionEvaluationTracking_MO] PRIMARY KEY NONCLUSTERED HASH 
	(
		[ID]
	) WITH ( BUCKET_COUNT = 64 )
) WITH ( MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA )
GO
ALTER TABLE [dbo].[DynamicConditionEvaluationTracking] ADD  CONSTRAINT [DF_DynamicConditionEvaluationTracking_Enabled]  DEFAULT ((0)) FOR [Enabled]
GO
ALTER TABLE [dbo].[DynamicConditionEvaluationTracking] ADD  CONSTRAINT [DF_DynamicConditionEvaluationTracking_DateCreatedUTC]  DEFAULT (getutcdate()) FOR [DateCreatedUTC]
GO


CREATE TABLE [dbo].[DynamicConditionEvaluationValueTypes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ValueTypeID] [nvarchar](36) NOT NULL,
	[Description] [nvarchar](128) NOT NULL,
	[Enabled] [bit] NOT NULL,
	CONSTRAINT [PK_DynamicConditionEvaluationValueTypes] PRIMARY KEY CLUSTERED 
	(
		[ID] ASC
	)
)
GO
ALTER TABLE [dbo].[DynamicConditionEvaluationValueTypes] ADD CONSTRAINT [DF_DynamicConditionEvaluationValueTypes_Enabled] DEFAULT ((1)) FOR [Enabled]
GO

CREATE TABLE [dbo].[DynamicConditionEvaluationObjectTypePerformanceCategory]
(
	[ObjectTypeID] nvarchar(36) NOT NULL,
	[PerformanceAnalysisCounterCategoryID] smallint NOT NULL
	CONSTRAINT [PK_DynamicConditionEvaluationObjectTypePerformanceCategory] PRIMARY KEY CLUSTERED 
	(
		[ObjectTypeID], [PerformanceAnalysisCounterCategoryID]
	)
);
GO

CREATE TABLE [Staging].[MO_DynamicConditionEvaluationResults]
(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ConditionID] [uniqueidentifier] NOT NULL,
	[ObjectID] [uniqueidentifier] NOT NULL,
	[CounterID] [smallint] NOT NULL,
	[Timestamp] [int] NOT NULL,
	[TimestampAligned] [int] NULL,
	[Value] [float] NOT NULL,
	[InstanceName] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
PRIMARY KEY NONCLUSTERED 
	(
		[ID] ASC
	)
) WITH ( MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY )
GO


CREATE TRIGGER [dbo].[trgLogACEvaluationResults]
	ON [dbo].[DynamicConditionStatus]
	WITH NATIVE_COMPILATION, SCHEMABINDING
	AFTER UPDATE
AS BEGIN ATOMIC WITH
(
	TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english'
)

IF NOT UPDATE([LastEvaluationResults]) --only log when results are updated. prevents dups.
	RETURN;

--This check avoids any joins to the tracking table, and also mitigates against issues from multiple inserted table rows... which should never happen on DCS.
DECLARE @ConditionID nvarchar(36);
DECLARE @ObjectID nvarchar(36);
SELECT TOP 1
	 @ConditionID = ConditionID
	,@ObjectID = ObjectID
FROM inserted;

SET @ConditionID =
	(
		SELECT TOP 1
				ConditionID
		FROM [dbo].[DynamicConditionEvaluationTracking]
		WHERE ConditionID = @ConditionID
				AND
				(
					ObjectID = @ObjectID
					OR ObjectID IS NULL
				)
	);

IF (@ConditionID IS NULL)
	RETURN;

INSERT INTO [Staging].[MO_DynamicConditionEvaluationResults]
(
	 [ConditionID]
	,[ObjectID]
	,[CounterID]
	,[Timestamp]
	,[Value]
	,[InstanceName]
)
SELECT
	 [ConditionID]
	,[ObjectID]
	,[CounterID]
	,DATEDIFF(second, '20000101 00:00:00', GETUTCDATE()) / 5
	,[Value]
	,COALESCE([ValueKeyDisplayValue], [ValueKey])
FROM 
(
	SELECT
		 cs.[ConditionID]
		,cs.[ObjectID]
		,et.[CounterID]
		,vr.[Value]
		,vr.[ValueKey]
		,vr.[ValueKeyDisplayValue]
	FROM inserted cs
	CROSS APPLY OPENJSON(cs.[LastEvaluationResults], '$.ValueRetrieverResults')
	WITH
		(
			 [UniqueKey] nvarchar(4000) '$.UniqueKey'
			,[Value] nvarchar(50) '$.Value'
			,[ValueKey] nvarchar(4000) '$.ValueKey'
			,[ValueKeyDisplayValue] nvarchar(4000) '$.ValueKeyDisplayValue'
		) AS vr
	JOIN [dbo].[DynamicConditionEvaluationTracking] et
	  ON et.UniqueKey = vr.UniqueKey
	WHERE cs.[LastEvaluationState] = 0 --completed successfully.
	  AND et.[ConditionID] = @ConditionID
	  AND et.[Enabled] = 1
	  AND vr.[Value] IS NOT NULL
) er

END
GO



/*** Proc for Enabling/Disabling AC Tracking ***/
/*
exec SetAdvisoryConditionEvaluationTracking N'High tempdb Version Store KB'; --SQL Server Query
exec SetAdvisoryConditionEvaluationTracking N'High Active User Sessions'; --SQL Server Query
exec SetAdvisoryConditionEvaluationTracking N'Service Broker - Task Limit Reached / Sec'; --User Counter
exec SetAdvisoryConditionEvaluationTracking N'High Read Latency', null, 1; --User Counter

SELECT * FROM [dbo].[PerformanceAnalysisCounter] WHERE ID >= 10000 ORDER BY ID;
SELECT * FROM [dbo].[DynamicConditionEvaluationTracking] ORDER BY ID;
*/
CREATE PROC [dbo].[SetAdvisoryConditionEvaluationTracking]
	 @ConditionName nvarchar(128) --Advisory Condition name
	,@ObjectID uniqueidentifier = NULL --(optional) reserved for future use
	,@Enabled bit = 1 --(optional) 1=enable, 0=disable
AS
SET NOCOUNT ON;
DECLARE @output_msg nvarchar(max);

--First update enabled status and object, which also lets us check for existence to avoid adding dups.
UPDATE [DynamicConditionEvaluationTracking]
SET  [Enabled] = @Enabled
	,[ObjectID] = @ObjectID
	,[UpdatedByUser] = SUSER_SNAME()
	,[DateUpdatedUTC] = GETUTCDATE()
FROM [DynamicConditionEvaluationTracking] et
JOIN
	(
		SELECT DISTINCT
			 [ConditionID]
			,[Name]
		FROM [DynamicConditionDefinition]
	) d
  ON d.ConditionID = et.ConditionID
WHERE d.[Name] = @ConditionName;

IF (@@ROWCOUNT > 0)
  BEGIN
	SET @output_msg = N'Tracking ' + CASE WHEN @Enabled = 0 THEN N'DISABLED' ELSE N'ENABLED' END + N' for ''' + @ConditionName + N'''.';
	RAISERROR(@output_msg, 0, 1);
	RETURN;
  END

DECLARE @ConditionInfo TABLE
(
	[ConditionID] [uniqueidentifier] NOT NULL,
	[DynamicConditionID] [int] NOT NULL,
	[ConditionName] [nvarchar](128) NOT NULL,
	[PerformanceAnalysisCounterCategoryID] [smallint] NOT NULL,
	[ValueTypeID] [nvarchar](100) NULL,
	[CounterID] [int] NULL,
	[CategoryName] [nvarchar](1000) NULL,
	[CounterName] [nvarchar](1000) NULL,
	[InstanceType] [int] NULL,
	[InstanceName] [nvarchar](1000) NULL,
	[InstanceNameFriendly] [nvarchar](1000) NULL,
	[Database] [nvarchar](128) NULL,
	[Query] [nvarchar](4000) NULL,
	[PerformanceCounterValueRetrievalType] [int] NULL,
	[UniqueKey] [nvarchar](4000) NULL,
	[RuleDefinition] [nvarchar](max) NOT NULL
);

;WITH MaxVersions
AS
(
	SELECT
		 ConditionID
		,MAX(VersionNumber) AS MaxVersionNumber
	FROM DynamicConditionDefinition
	GROUP BY ConditionID
)
INSERT INTO @ConditionInfo
SELECT
	 cd.ConditionID	
	,cd.ID AS DynamicConditionID
	,cd.[Name] As ConditionName
	,pc.PerformanceAnalysisCounterCategoryID
	,rd.ValueTypeID
	,rd.CounterID
	,rd.CategoryName
	,rd.CounterName
	,rd.InstanceType
	,rd.InstanceName
	,rd.InstanceNameFriendly
	,rd.[Database]
	,rd.Query
	,rd.PerformanceCounterValueRetrievalType
	,UniqueKey = rd.ValueTypeID +
					CASE
						WHEN rd.CounterID IS NOT NULL
							THEN N'/' + CAST(rd.CounterID as nvarchar(10))
						WHEN rd.CounterName IS NOT NULL
							THEN N'/' + rd.CategoryName
							   + N'/' + rd.CounterName
							   + CASE ISNULL(rd.InstanceType, -1)
									WHEN -1 THEN N'//'
									WHEN 0 THEN N'/Total/'
									ELSE N''
								 END
						ELSE
							CASE WHEN rd.[Database] IS NOT NULL
								THEN N'/' + rd.[Database]
								ELSE N''
							END
							+ N'/' + rd.[Query]
					END
	,cd.RuleDefinition
FROM DynamicConditionDefinition cd
JOIN MaxVersions mv
  ON cd.ConditionID = mv.ConditionID
 AND cd.VersionNumber = mv.MaxVersionNumber
LEFT JOIN dbo.DynamicConditionEvaluationObjectTypePerformanceCategory pc
  ON cd.AppliesToObjectTypeID = pc.ObjectTypeID
CROSS APPLY OPENJSON([RuleDefinition], '$.Children')
	WITH
		(
			 ValueTypeID nvarchar(100)					'$.Left.ValueTypeID'				--aa61ee90-8a95-4fdf-a208-b9a4afa26d9d=SQL Server Query, f2e88d72-73c6-4ce1-b92a-029c313e707f=S1 Database Query, bd31f3db-a9ba-45fe-a076-9b5f4a386ff0=User Perf Counter
			,PerformanceCategoryType int				'$.Left.PerformanceCategoryType'	--0=Windows, 1=SqlServer, 2=Ssas, 3=Aps, 4=Tintri, 5=Vmware, 6=SqlDb, 7=AmazonRds
			,CounterID int								'$.Left.CounterID'					--Base or virtual counter ID. If null and CounterName is not null, then it's a User Perf Counter.
			,CounterName nvarchar(1000)					'$.Left.CounterName'
			,CategoryName nvarchar(1000)				'$.Left.CategoryName'
			,InstanceType int							'$.Left.InstanceType'				--0=Total, 1=Any, 2=Equals, 3=DoesNotEqual, 4=Contains, 5=StartsWith, 6=EndsWith, 7=RegexMatch
			,InstanceName nvarchar(1000)				'$.Left.InstanceName'
			,InstanceNameFriendly nvarchar(1000)		'$.Left.InstanceNameFriendly'
			,[Database] nvarchar(128)					'$.Left.Database'					--null for S1 Database Queries
			,Query nvarchar(4000)						'$.Left.Query'
			,PerformanceCounterValueRetrievalType int	'$.Left.PerformanceCounterValueRetrievalType' --0=Value, 1=Baseline
		) AS rd
WHERE rd.ValueTypeID IN
	(
		SELECT ValueTypeID
		FROM DynamicConditionEvaluationValueTypes
		WHERE Enabled = 1
	)
  AND cd.[Name] = @ConditionName;

DECLARE @ConditionID uniqueidentifier;
DECLARE @DynamicConditionID int;
DECLARE @CounterCategoryID smallint;
DECLARE @UniqueKey nvarchar(4000);

--Load vars for first op only.
SELECT TOP 1
	 @ConditionID = ConditionID
	,@DynamicConditionID = DynamicConditionID
	,@CounterCategoryID = PerformanceAnalysisCounterCategoryID
	,@UniqueKey = UniqueKey
FROM @ConditionInfo;

IF (@ConditionID IS NULL)
  BEGIN
	SET @output_msg = N'Condition ''' + @ConditionName + N''' not found or type not supported.';
	RAISERROR(@output_msg, 11, 1);
	RETURN;
  END
ELSE IF (@CounterCategoryID IS NULL)
  BEGIN
	SET @output_msg = N'Condition object type not supported.';
	RAISERROR(@output_msg, 11, 1);
	RETURN;
  END

--Setup counter vars.
DECLARE @CounterResourceName varchar(42);
SET @CounterResourceName = UPPER(REPLACE(REPLACE(REPLACE(REPLACE(@ConditionName, ' ', '_'), '''', ''), '/', '_'), '\', '_'));
DECLARE @CounterBaseID smallint = 9999;
DECLARE @CounterID smallint;
SET @CounterID = (SELECT ISNULL(MAX(ID), @CounterBaseID) + 1 FROM PerformanceAnalysisCounter WHERE ID >= @CounterBaseID);
--Output counter info.
SELECT
	 CounterID = @CounterID
	,CounterResourceName = @CounterResourceName;

--Add new AC counter.
SET IDENTITY_INSERT [dbo].[PerformanceAnalysisCounter] ON;
INSERT INTO [dbo].[PerformanceAnalysisCounter]
(
	 [ID]
	,[PerformanceAnalysisCounterCategoryID]
	,[PerformanceAnalysisSampleIntervalID]
	,[CounterResourceName]
	,[CounterName]
	,[PerformanceAnalysisCounterSampleType]
	,[InstanceFilter]
	,[IsBaselineApproved]
)
VALUES
(
	 @CounterID
	,@CounterCategoryID
	,0
	,@CounterResourceName
	,@ConditionName
	,0
	,null
	,null
);
SET IDENTITY_INSERT [dbo].[PerformanceAnalysisCounterCategory] OFF;

--Add AC tracking row.
INSERT INTO [dbo].[DynamicConditionEvaluationTracking]
(
	 [ConditionID]
	,[DynamicConditionID]
	,[UniqueKey]
	,[ObjectID]
	,[CounterID]
	,[Enabled]
	,[CreatedByUser]
	,[DateCreatedUTC]
)
VALUES
(
	 @ConditionID
	,@DynamicConditionID
	,@UniqueKey
	,@ObjectID
	,@CounterID
	,@Enabled
	,SUSER_SNAME()
	,GETUTCDATE()
);

IF (@@ROWCOUNT > 0)
  BEGIN
	SET @output_msg = N'Tracking initialized for ''' + @ConditionName + N''' as ' + CASE WHEN @Enabled = 0 THEN N'DISABLED' ELSE N'ENABLED' END + N'.';
	RAISERROR(@output_msg, 0, 1);
  END
ELSE
  BEGIN
	SET @output_msg = N'Tracking NOT initialized for ''' + @ConditionName + N'''.';
	RAISERROR(@output_msg, 11, 1);
  END

RETURN
GO


/*** Add new Counter Category ***/
set identity_insert [dbo].[PerformanceAnalysisCounterCategory] ON;
INSERT INTO [dbo].[PerformanceAnalysisCounterCategory]
(
	 [ID]
	,[CategoryResourceName]
	,[CategoryTypes]
	,[NumberOfCounters]
	,[PerformanceAnalysisSampleIntervalID]
	,[IsDeviceLevel]
	,[HistoryDataRetentionHours]
	,[PerformanceAnalysisCounterDataPartitionID]
	,[MinRollupLevelBreakMinutes]
	,[AllowReportOverride]
	,[HasInstances]
	,[CategoryName]
)
VALUES
(
	 1000
	,'SYSPERF:SQL_AC_EVAL_RESULTS'
	,1158
	,1
	,null
	,0
	,72
	,null
	,0
	,1
	,1
	,'Advisory Conditions (SQL Server)'
),
(
	 1001
	,'SYSPERF:WIN_AC_EVAL_RESULTS'
	,129
	,1
	,null
	,1
	,72
	,null
	,0
	,1
	,1
	,'Advisory Conditions (Windows)'
);
set identity_insert [dbo].[PerformanceAnalysisCounterCategory] OFF;
GO

/*** Add ObjectType to CategoryID mapping table ***/
INSERT INTO dbo.DynamicConditionEvaluationObjectTypePerformanceCategory
	(
		ObjectTypeID,
		PerformanceAnalysisCounterCategoryID
	)
VALUES
	(
		N'0A11A887-823A-4461-87AF-321CAD1C3623',
		1000
	),
	(
		N'49A296EA-155F-4347-8D33-481FC53B6492',
		1001
	),
	(
		N'894DE672-3FC0-4779-9A0D-880D4C207C77',
		1001
	);
GO

/*** Add Supported Counter Value Types ***/
INSERT INTO [dbo].[DynamicConditionEvaluationValueTypes]
	(
		ValueTypeID,
		[Description]
	)
VALUES
	 (N'aa61ee90-8a95-4fdf-a208-b9a4afa26d9d', N'SQL Server Query')
	,(N'bd31f3db-a9ba-45fe-a076-9b5f4a386ff0', N'User Performance Counter');
	--,(N'f2e88d72-73c6-4ce1-b92a-029c313e707f', N'SentryOne Database Query');
GO