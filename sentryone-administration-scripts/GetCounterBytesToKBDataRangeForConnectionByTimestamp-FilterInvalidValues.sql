ALTER PROCEDURE [dbo].[GetCounterBytesToKBDataRangeForConnectionByTimestamp]
		  @DeviceID smallint
		, @ConnectionID smallint
		, @CounterID smallint
		, @StartTimestamp int
		, @EndTimestamp int
		, @RangeSizeMinutes int = 0
AS

SET NOCOUNT ON

DECLARE @RollupLevelID smallint
SET @RollupLevelID = dbo.fnRollupLevelForRangeSizeInMinutes(@RangeSizeMinutes, @StartTimestamp)
--print '@RollupLevelID=' + cast(@RollupLevelID as varchar(5))

DECLARE @SQLStmt nvarchar(4000), @SQLParams nvarchar(1000)
DECLARE @RollupSuffix varchar(20)
IF (@RollupLevelID = 0)
  BEGIN
	SET @RollupSuffix = (SELECT dbo.fnGetDataPartitionSuffixForCounter(@CounterID))

	--If a single sample is being retrieved, we need to verify that it exists since the chart selection interval may not be in sync
	--with the sample interval for this counter. Collection delays may also cause a sample to not land on an even sample interval.
	IF (@StartTimestamp = @EndTimestamp)
	  BEGIN
		CREATE TABLE #LastTimestampTable (LastTimestamp int)
		DECLARE @LastTimestamp int
		DECLARE @MinTimestamp int
		--Only check over the last 90 seconds prior to the sample. Before that isn't really valid to show for the current sample. This will also increase performance.
		SET @MinTimestamp =	(@StartTimestamp - (90/5))

		SET @SQLStmt =
			N'INSERT INTO #LastTimestampTable (LastTimestamp)
			SELECT MAX(Timestamp)
			FROM dbo.PerformanceAnalysisData WITH (NOLOCK)
			WHERE DeviceID = @DeviceID
			 AND EventSourceConnectionID = @ConnectionID
			 AND PerformanceAnalysisCounterID = @CounterID
			 AND Timestamp <= @StartTimestamp
			 AND Timestamp >= @MinTimestamp'
		SET @SQLStmt = REPLACE(@SQLStmt, 'PerformanceAnalysisData', 'PerformanceAnalysisData' + @RollupSuffix)

		SET @SQLParams =
			N'@DeviceID smallint
			,@ConnectionID smallint
			,@CounterID smallint
			,@StartTimestamp int
			,@MinTimestamp int'

		EXEC sp_executesql
				 @SQLStmt
				,@SQLParams
					,@DeviceID = @DeviceID
					,@ConnectionID = @ConnectionID
					,@CounterID = @CounterID
					,@StartTimestamp = @StartTimestamp
					,@MinTimestamp = @MinTimestamp

		SET @LastTimestamp =
			(SELECT LastTimestamp
			 FROM #LastTimestampTable)

		SELECT @StartTimestamp = @LastTimestamp
			, @EndTimestamp = @LastTimestamp

		DROP TABLE #LastTimestampTable
	  END
  END
ELSE
	SET @RollupSuffix = 'Rollup' + CAST(@RollupLevelID as varchar(2))
	
SET @SQLStmt =
	N'SELECT dateadd(second, Timestamp * 5, ''20000101 00:00:00'') AS Timestamp
		--, Value as RawVal
		, (Value / 1024) AS Value
		, InstanceName
	FROM dbo.PerformanceAnalysisData WITH (NOLOCK)
	WHERE DeviceID = @DeviceID
	 AND EventSourceConnectionID = @ConnectionID
	 AND PerformanceAnalysisCounterID = @CounterID
	 AND Timestamp >= @StartTimestamp
	 AND Timestamp <= @EndTimestamp
	 AND Value >= 0 --protects against negative values from sys.dm_os_performance_counters, as seen from SQLServer:Memory Node->Free Node Memory (KB).
	 AND Value < 107374182400 --protects against abnormally high values from PDH (>=100GB if input bytes|100TB if input KB), as seen from SQLServer:Memory Node->Free Node Memory (KB).
	ORDER BY Timestamp ASC, InstanceName ASC'

SET @SQLStmt = REPLACE(@SQLStmt, 'PerformanceAnalysisData', 'PerformanceAnalysisData' + @RollupSuffix)
--print @SQLStmt

SET @SQLParams =
	N'@DeviceID smallint
	,@ConnectionID smallint
	,@CounterID smallint
	,@StartTimestamp int
	,@EndTimestamp int'

EXEC sp_executesql
		 @SQLStmt
		,@SQLParams
			,@DeviceID = @DeviceID
			,@ConnectionID = @ConnectionID
			,@CounterID = @CounterID
			,@StartTimestamp = @StartTimestamp
			,@EndTimestamp = @EndTimestamp