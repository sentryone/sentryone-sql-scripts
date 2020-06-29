;WITH TotalDaysPerTable
AS
(
	SELECT
		 cs.object_id
		,index_id
		,RollupID = rl.ID
		,rl.LevelBreakMinutes
		,table_name = object_name(cs.object_id)
		,pt.TableType
		,total_days = DATEDIFF(day, MIN(cs.created_time), getdate())
		,retention_days = MAX(pt.RetentionHours) / 24
	FROM sys.dm_db_column_store_row_group_physical_stats cs
	JOIN [Partitioning].[PartitionTracking] pt
	  ON 'PerformanceAnalysisData' + pt.Suffix = object_name(cs.object_id)
	LEFT JOIN PerformanceAnalysisDataRollupLevel rl
	  ON 'PerformanceAnalysisDataRollup' + cast(rl.ID AS varchar(2)) = object_name(cs.object_id)
	WHERE cs.state <> 4
	  AND CASE WHEN rl.ID is null THEN 1 ELSE rl.Enabled END = 1
	GROUP BY
		 object_id
		,index_id
		,rl.ID
		,rl.LevelBreakMinutes
		,pt.TableType
)
,TotalBytesPerDay
AS
(
	SELECT 
		 d.object_id
		,d.index_id
		,d.RollupID
		,d.LevelBreakMinutes
		,d.table_name
		,d.TableType
		,tot_bytes = SUM(used_page_count) * 8192
		,tot_bytes_per_day = (SUM(used_page_count) * 8192) / d.total_days
	FROM TotalDaysPerTable d
	JOIN sys.dm_db_partition_stats ps
	  ON ps.object_id = d.object_id
	 AND ps.index_id = d.index_id
	GROUP BY 
		 d.object_id
		,d.index_id
		,d.RollupID
		,d.LevelBreakMinutes
		,d.table_name
		,d.TableType
		,d.total_days
)
,TotalRawBytesPerDay
AS
(
	SELECT
		 tot_bytes = SUM(tot_bytes) 
		,tot_bytes_per_day = SUM(tot_bytes_per_day)
	FROM TotalBytesPerDay
	WHERE TableType = 1
)
SELECT
	 RollupID = 0
	,LevelBreakMinutes = 0
	,table_name = 'raw data'
	,tot_mb = (tot_bytes / 1048576)
	,tot_mb_per_day = (tot_bytes_per_day / 1048576)
	,pct_of_raw_data = 100.0
FROM TotalRawBytesPerDay
	UNION
SELECT
	 RollupID
	,LevelBreakMinutes
	,table_name
	,tot_mb = (tot_bytes / 1048576)
	,tot_mb_per_day = (tot_bytes_per_day / 1048576)
	,pct_of_raw_data = CAST((CAST(tot_bytes_per_day AS float)
								/ (SELECT tot_bytes_per_day FROM TotalRawBytesPerDay)) * 100 AS decimal(4,1))
FROM TotalBytesPerDay
WHERE TableType = 2
ORDER BY LevelBreakMinutes;
