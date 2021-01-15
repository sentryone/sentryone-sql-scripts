/*
	README:  https://docs.sentryone.com/help/data-capacity-planning
*/

SELECT
TableName = OBJECT_SCHEMA_NAME([object_id]) + '.' + OBJECT_NAME([object_id]),
[RowCount] = SUM(CASE WHEN index_id IN (0,1) THEN row_count ELSE 0 END),
UsedSpaceMB = SUM(used_page_count / 128),
ReservedSpaceMB = SUM(reserved_page_count / 128)
FROM sys.dm_db_partition_stats
WHERE OBJECT_NAME([object_id]) IN
(
'BlockChainDetail',
'EventSourceHistory',
'MetaHistorySqlServerBlockLog',
'MetaHistorySqlServerTraceLog',
'PerformanceAnalysisData',
'PerformanceAnalysisDataDatabaseCounter',
'PerformanceAnalysisDataDiskCounter',
'PerformanceAnalysisDataRollup11',
'PerformanceAnalysisDataRollup2',
'PerformanceAnalysisDataRollup4',
'PerformanceAnalysisDataRollup6',
'PerformanceAnalysisDataRollup8',
'PerformanceAnalysisTraceData',
'PerformanceAnalysisPlan',
'PerformanceAnalysisPlanOpTotals',
'PerformanceAnalysisTraceCachedPlanItems',
'PerformanceAnalysisTraceDataToCachedPlans',
'PerformanceAnalysisTraceQueryStats',
'MetaHistorySharePointTimerJob',
'PerformanceAnalysisSsasUsageTotals',
'PerformanceAnalysisSsasCubeDimensionAttribute',
'PerformanceAnalysisSsasTraceDataDetail'
)
AND OBJECTPROPERTY([object_id], 'IsUserTable') = 1
GROUP BY [object_id]
ORDER BY TableName;