/*** Script to increase SentryOne chart resolution and performance data retention ***
IMPORTANT:
	The SentryOne Scalability Pack must be installed first (partitioned CCI + In-mem OLTP)
	https://docs.sentryone.com/help/recommendations#scalabilitypack

USAGE:
	You can simply run the entire script as-is, or adjust parameters as follows:
	- @MinDatapoints and @MaxDatapoints to affect chart range sizes
	- @BaseRetentionHours and @ScaleFactor to affect data retention
	- Optionally disable 2- and 3- day rollup tables (see notes inline below)

DISCLAIMER: These updates are considered preview, and should be used at your own risk.

Copyright 2020 SQL Sentry, LLC	
*/

set nocount on;

--Chart range size variables:
declare @MinDatapoints int = 50;
declare @MaxDatapoints int = 480;

--Retention variables:
declare @BaseRetentionHours float; --Retention hours for raw data. Rollup retention is calc'd off of this as the baseline.
declare @ScaleFactor float; --Scales retention of rollup data relative to raw data. Lower values increase retention. Keep between 1.5 and 4.0.
declare @MinResolutionMinutes float = 1.0/3.0; --20 sec avg for raw data--shouldn't need to change. Higher numbers will reduce rollup retention and increase max chart range size for raw data.
/* Uncomment the line below for the desired combination, or adjust parameters as needed: */
--select @BaseRetentionHours = 240.0, @ScaleFactor = 3.0; --conservative
select @BaseRetentionHours = 360.0, @ScaleFactor = 2.5; --default
--select @BaseRetentionHours = 480.0, @ScaleFactor = 2.0; --extreme

--Preview calcs:
select 
	 LevelBreakMinutes
	,MinChartRangeSizeMinutes = LevelBreakMinutes * @MinDatapoints
	,MaxChartRangeSizeMinutes = LevelBreakMinutes * @MaxDatapoints 
	,RetentionDays = CAST(1.0/(@MinResolutionMinutes / CAST(LevelBreakMinutes as float)) * (@BaseRetentionHours / 24)
					* (POWER(CAST(LevelBreakMinutes as float), 1.0/@ScaleFactor) / CAST(LevelBreakMinutes as float)) as int)
from PerformanceAnalysisDataRollupLevel
where Enabled = 1
order by LevelBreakMinutes;

select
	 RawDataTable = N'PerformanceAnalysisData' +  Suffix
	,RetentionDays = @BaseRetentionHours / 24
from Partitioning.PartitionTracking pt
where TableType = 1
  and Enabled = 1
  and Suffix <> N'Aggregate';

--Update min/max chart ranges:
update PerformanceAnalysisDataRollupLevel
set MinChartRangeSizeMinutes = LevelBreakMinutes * @MinDatapoints
	,MaxChartRangeSizeMinutes = LevelBreakMinutes * @MaxDatapoints
where LevelBreakMinutes > 0;

--Add new placeholder row for raw data:
delete PerformanceAnalysisDataRollupLevel
where LevelBreakMinutes = 0;

insert into PerformanceAnalysisDataRollupLevel
	(ID, LevelBreakMinutes, MinChartRangeSizeMinutes, MaxChartRangeSizeMinutes, Enabled)
values
	(0, 0, 0, ROUND(@MaxDatapoints * @MinResolutionMinutes, 0), 0);

--Increase performance data retention:
update Partitioning.PartitionTracking
set RetentionHours = 1.0/(@MinResolutionMinutes / CAST(LevelBreakMinutes as float)) * @BaseRetentionHours
					* (POWER(CAST(LevelBreakMinutes as float), 1.0/@ScaleFactor) / CAST(LevelBreakMinutes as float))
from Partitioning.PartitionTracking pt
join PerformanceAnalysisDataRollupLevel rl
  on 'Rollup' + cast(rl.ID as nvarchar(2)) = Suffix;

update Partitioning.PartitionTracking
set RetentionHours = @BaseRetentionHours
from Partitioning.PartitionTracking pt
where TableType = 1
  and Enabled = 1
  and Suffix <> 'Aggregate';

/*** OPTIONAL *** [comment out this line to enable this section of the script]
--Will clear out all data from the 2- and 3-day rollup tables.
--Partitioning scheme will be left intact in case they are ever reenabled.
--Data can always be repopulated from 1-day rollups by reenabling and setting LastRollupTimestamp=0 for these levels.

update PerformanceAnalysisDataRollupLevel
set Enabled = 0
where ID IN (12, 13);

truncate table [dbo].[PerformanceAnalysisDataRollup12];
go
truncate table [dbo].[PerformanceAnalysisDataRollup13];
go

--Remove upper range limit for new max level (1-day):
update PerformanceAnalysisDataRollupLevel
set MaxChartRangeSizeMinutes = 999999999
where ID = 11;
--*** OPTIONAL ***/

--Verify updates:
select
	 LevelBreakMinutes
	,MinChartRangeSizeMinutes
	,MaxChartRangeSizeMinutes
from PerformanceAnalysisDataRollupLevel
where Enabled = 1
   or LevelBreakMinutes = 0
order by LevelBreakMinutes;

select
	 Suffix
	,RollupMinutes = rl.LevelBreakMinutes
	,RetentionDays = (RetentionHours / 24)
from Partitioning.PartitionTracking pt
left join PerformanceAnalysisDataRollupLevel rl
  on N'Rollup' + cast(rl.ID as nvarchar(2)) = Suffix
where pt.TableType = 1
   or rl.Enabled = 1
order by TableType, rl.LevelBreakMinutes, Suffix;


/*** Schema Updates ***/
--Update rollup function definitions:
DROP FUNCTION [dbo].[fnRollupLevelForRangeSizeInMinutes]
GO

DROP FUNCTION [dbo].[fnRollupLevelForRangeSizeAndCounterInMinutes]
GO

CREATE FUNCTION [dbo].[fnRollupLevelForRangeSizeInMinutes]
(
	 @RangeSizeMinutes int
	,@StartTimestamp int = 999999999
)
RETURNS smallint
AS

BEGIN
	DECLARE @RollupLevelID AS smallint;
	DECLARE @SmallestMatchingLevelID AS smallint;
	DECLARE @SmallestMatchingLevelIDWithFullData AS smallint;
	DECLARE @MinPartitionBoundaryValue AS int;

	SET @SmallestMatchingLevelID =
		(
			SELECT TOP 1 ID
			FROM dbo.PerformanceAnalysisDataRollupLevel
			WHERE MinChartRangeSizeMinutes < @RangeSizeMinutes
			  AND MaxChartRangeSizeMinutes >= @RangeSizeMinutes
			  AND (Enabled = 1 OR LevelBreakMinutes = 0)
			ORDER BY LevelBreakMinutes ASC
		);

	IF (@SmallestMatchingLevelID = 0) --Raw Data
	  BEGIN
		--Get the oldest boundary timestamp -- won't include older data in this partition but it's the best we can do and stay lightweight.
		SET @MinPartitionBoundaryValue =
			(
				SELECT CAST(MIN(prf.value) as int)
				FROM sys.partition_functions pf
				JOIN sys.partition_range_values prf
					ON pf.function_id = prf.function_id
				WHERE pf.name = 'PerformanceDataCurrentFunction'
			);

		IF (@MinPartitionBoundaryValue < @StartTimestamp)
		  BEGIN
			SET @SmallestMatchingLevelIDWithFullData = 0;
		  END
	  END

	IF (@SmallestMatchingLevelIDWithFullData IS NULL)
	  BEGIN
		SET @SmallestMatchingLevelIDWithFullData =
			(
				SELECT TOP 1 ID
				FROM dbo.PerformanceAnalysisDataRollupLevel
				WHERE MinChartRangeSizeMinutes < @RangeSizeMinutes
				  AND MaxChartRangeSizeMinutes >= @RangeSizeMinutes
				  AND LastPurgeBeforeTimestamp <= @StartTimestamp
				  AND Enabled = 1
				ORDER BY LevelBreakMinutes ASC
			);
	  END
	
	SELECT @RollupLevelID = COALESCE(@SmallestMatchingLevelIDWithFullData, @SmallestMatchingLevelID, 0);

	DECLARE @MinUploadRollupLevelID AS smallint;
	SET @MinUploadRollupLevelID = 
		(
			SELECT TOP 1 MinimumUploadRollupLevelID
			FROM ApplicationSettings
		);

	IF(@MinUploadRollupLevelID IS NOT NULL AND @MinUploadRollupLevelID > @RollupLevelID)
	BEGIN
		SET @RollupLevelID = @MinUploadRollupLevelID;
	END

	RETURN @RollupLevelID
END
GO

CREATE FUNCTION [dbo].[fnRollupLevelForRangeSizeAndCounterInMinutes]
(
	 @RangeSizeMinutes int
	,@StartTimestamp int = 999999999
	,@CounterID smallint
)
RETURNS smallint
AS

BEGIN
	DECLARE @RollupLevelID AS smallint
	DECLARE @SmallestMatchingLevelID AS smallint
	DECLARE @SmallestMatchingLevelIDWithFullData AS smallint
	DECLARE @MinBreakLevelMinutes AS smallint
	DECLARE @MinPartitionBoundaryValue AS int;

	SET @MinBreakLevelMinutes =
		(
			SELECT MAX(GetMinutes)
			FROM
				(
					SELECT GetMinutes = SI.IntervalInTicks / 10000000 / 60
					FROM PerformanceAnalysisCounter PC
					INNER JOIN PerformanceAnalysisSampleInterval SI
					   ON SI.ID = PC.PerformanceAnalysisSampleIntervalID
					WHERE PC.ID = @CounterID
						UNION ALL
					SELECT GetMinutes = Cat.MinRollupLevelBreakMinutes
					FROM PerformanceAnalysisCounter PC
					INNER JOIN PerformanceAnalysisCounterCategory Cat
					   ON Cat.ID = PC.PerformanceAnalysisCounterCategoryID
					WHERE PC.ID = @CounterID		
				) MinBreakLevelMinutes
		)
	
	SET @SmallestMatchingLevelID =
		(
			SELECT TOP 1 ID
			FROM dbo.PerformanceAnalysisDataRollupLevel
			WHERE MinChartRangeSizeMinutes < @RangeSizeMinutes
			  AND MaxChartRangeSizeMinutes >= @RangeSizeMinutes
			  AND @MinBreakLevelMinutes <= LevelBreakMinutes
			  AND (Enabled = 1 OR LevelBreakMinutes = 0)
			ORDER BY LevelBreakMinutes ASC
		);

	IF (@SmallestMatchingLevelID = 0) --Raw Data
	  BEGIN
		--Get the oldest boundary timestamp -- won't include older data in this partition but it's the best we can do and stay lightweight.
		SET @MinPartitionBoundaryValue =
			(
				SELECT cast(MIN(prf.value) as int)
				FROM sys.partition_functions pf
				JOIN sys.partition_range_values prf
					ON pf.function_id = prf.function_id
				WHERE pf.name = 'PerformanceDataCurrentFunction'
			);

		IF (@MinPartitionBoundaryValue < @StartTimestamp)
		  BEGIN
			SET @SmallestMatchingLevelIDWithFullData = 0;
		  END
	  END

	IF (@SmallestMatchingLevelIDWithFullData IS NULL)
	  BEGIN
		SET @SmallestMatchingLevelIDWithFullData =
			(
				SELECT TOP 1 ID
				FROM dbo.PerformanceAnalysisDataRollupLevel
				WHERE MinChartRangeSizeMinutes < @RangeSizeMinutes
				  AND MaxChartRangeSizeMinutes >= @RangeSizeMinutes
				  AND LastPurgeBeforeTimestamp <= @StartTimestamp
				AND @MinBreakLevelMinutes <= LevelBreakMinutes
				AND Enabled = 1
				ORDER BY LevelBreakMinutes ASC
			);
	  END
	
	SELECT @RollupLevelID = COALESCE(@SmallestMatchingLevelIDWithFullData, @SmallestMatchingLevelID, 0);

	DECLARE @MinUploadRollupLevelID AS smallint;
	SET @MinUploadRollupLevelID = 
		(
			SELECT TOP 1 MinimumUploadRollupLevelID
			FROM ApplicationSettings
		);

	IF(@MinUploadRollupLevelID IS NOT NULL AND @MinUploadRollupLevelID > @RollupLevelID)
	BEGIN
		SET @RollupLevelID = @MinUploadRollupLevelID;
	END

	RETURN @RollupLevelID
END
GO

GRANT EXECUTE ON [dbo].[fnRollupLevelForRangeSizeInMinutes] TO [allow_all]
GO
GRANT EXECUTE ON [dbo].[fnRollupLevelForRangeSizeInMinutes] TO [allow_least_privilege]
GO
GRANT EXECUTE ON [dbo].[fnRollupLevelForRangeSizeAndCounterInMinutes] TO [allow_all]
GO
GRANT EXECUTE ON [dbo].[fnRollupLevelForRangeSizeAndCounterInMinutes] TO [allow_least_privilege]
GO


