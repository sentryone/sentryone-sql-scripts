/*
	Melissa Connors
	README: https://docs.sentryone.com/help/apply-sql-server-data-compression

	IMPORTANT
	Do not apply data compression to the tables in the PERFORMANCE COUNTER LIST if you have the SentryOne Scalability Pack applied.
	  The Scalability Pack has already converted these tables to use Columnstore indexes.
	
  You may apply compression to the tables under the EVENT AND OTHER LIST whether or not the Scalability Pack is applied.
*/

/*
	EVENT AND OTHER LIST
*/

-- EventSourceHistory

-- estimate compression savings
 EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'EventSourceHistory',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'PAGE';

SELECT index_id, name FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.EventSourceHistory');
 
-- alter indexes to use page compression
ALTER INDEX IX_MaxIDs ON dbo.EventSourceHistory 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_IncompleteRecs ON dbo.EventSourceHistory 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_Unique1 ON dbo.EventSourceHistory 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_Unique2 ON dbo.EventSourceHistory 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_FailedObjectsInRange ON dbo.EventSourceHistory 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_GlobalViews ON dbo.EventSourceHistory 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_DetailInserts ON dbo.EventSourceHistory 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

--Consider using ROW compression on the clustered index if index maintenance duration is a concern.
ALTER INDEX PK_EventHistory ON dbo.EventSourceHistory 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- EventSourceHistoryDetail

-- estimate compression savings
 EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'EventSourceHistoryDetail',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'ROW';

SELECT index_id, name FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.EventSourceHistoryDetail');

-- alter indexes to use row compression
ALTER INDEX PK_EventHistoryDetail ON dbo.EventSourceHistoryDetail 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = ROW);

ALTER INDEX IX_EventSourceHistoryID ON dbo.EventSourceHistoryDetail 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = ROW);

-- alter indexes to use page compression
ALTER INDEX IX_Unique2 ON dbo.EventSourceHistoryDetail 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_Unique1 ON dbo.EventSourceHistoryDetail 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_MasterDetailCorrelationTrigger ON dbo.EventSourceHistoryDetail 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_IncompleteRecs ON dbo.EventSourceHistoryDetail 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_MaxIDs ON dbo.EventSourceHistoryDetail 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisTraceData

-- estimate compression savings 
EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'PerformanceAnalysisTraceData',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'ROW';

SELECT index_id, name FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.PerformanceAnalysisTraceData');
 
-- alter indexes to use page compression
ALTER INDEX IX_MaxIDs ON dbo.PerformanceAnalysisTraceData 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_PerformanceAnalysisTraceData_Wide ON dbo.PerformanceAnalysisTraceData 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);
 
-- alter index to use row compression
ALTER INDEX PK_PerformanceAnalysisTraceData ON dbo.PerformanceAnalysisTraceData 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = ROW);

ALTER INDEX IX_PurgeProcess ON dbo.PerformanceAnalysisTraceData 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = ROW);

-- dbo.PerformanceAnalysisPlanOpTotals

-- estimate compression savings
 EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'PerformanceAnalysisPlanOpTotals',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'ROW';
 
SELECT index_id, name FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.PerformanceAnalysisPlanOpTotals');

-- alter indexes to use row compression
ALTER INDEX PK_PerformanceAnalysisTracePlanOpTotals ON dbo.PerformanceAnalysisPlanOpTotals 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = ROW);

ALTER INDEX IX_PerformanceAnalysisTracePlanOpTotals_Unique ON dbo.PerformanceAnalysisPlanOpTotals 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = ROW);

-- dbo.PerformanceAnalysisTraceQueryStats

-- estimate compression savings
 EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'PerformanceAnalysisTraceQueryStats',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'ROW';

SELECT index_id, name FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.PerformanceAnalysisTraceQueryStats');

-- alter indexes to use row compression
ALTER INDEX PK_PerformanceAnalysisTraceQueryStats ON dbo.PerformanceAnalysisTraceQueryStats 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = ROW);

ALTER INDEX IX_PurgeProcess ON dbo.PerformanceAnalysisTraceQueryStats 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = ROW);

-- alter indexes to use page compression
ALTER INDEX IX_PerformanceAnalysisTraceQueryStats_ObjectLookup ON dbo.PerformanceAnalysisTraceQueryStats 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

ALTER INDEX IX_PerformanceAnalysisTraceQueryStats_Unique ON dbo.PerformanceAnalysisTraceQueryStats 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);


/*
	PERFORMANCE COUNTER LIST
	Do not run these data compression scripts where the SentryOne Scalability Pack is applied.
*/
-- PerformanceAnalysisDataRollup2

-- estimate compression savings 
EXEC sys.sp_estimate_data_compression_savings 
@schema_name = N'dbo', 
@object_name = N'PerformanceAnalysisDataRollup2',
@index_id = NULL,
@partition_number = NULL, 
@data_compression = N'PAGE'; 

-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisDataRollup 
ON dbo.PerformanceAnalysisDataRollup2 
REBUILD PARTITION = ALL 
WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataRollup4

-- estimate compression savings 
EXEC sys.sp_estimate_data_compression_savings 
@schema_name = N'dbo', 
@object_name = N'PerformanceAnalysisDataRollup4',
@index_id = NULL,
@partition_number = NULL, 
@data_compression = N'PAGE'; 

-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisDataRollup ON dbo.PerformanceAnalysisDataRollup4 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataRollup6

-- estimate compression savings 
EXEC sys.sp_estimate_data_compression_savings 
@schema_name = N'dbo', 
@object_name = N'PerformanceAnalysisDataRollup6',
@index_id = NULL,
@partition_number = NULL, 
@data_compression = N'PAGE'; 

-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisDataRollup ON dbo.PerformanceAnalysisDataRollup6 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataRollup8

-- estimate compression savings 
EXEC sys.sp_estimate_data_compression_savings 
@schema_name = N'dbo', 
@object_name = N'PerformanceAnalysisDataRollup8',
@index_id = NULL,
@partition_number = NULL, 
@data_compression = N'PAGE'; 

-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisDataRollup ON dbo.PerformanceAnalysisDataRollup8 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataRollup11

-- estimate compression savings 
EXEC sys.sp_estimate_data_compression_savings 
@schema_name = N'dbo', 
@object_name = N'PerformanceAnalysisDataRollup11',
@index_id = NULL,
@partition_number = NULL, 
@data_compression = N'PAGE'; 

-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisDataRollup ON dbo.PerformanceAnalysisDataRollup11 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataRollup12

-- estimate compression savings 
EXEC sys.sp_estimate_data_compression_savings 
@schema_name = N'dbo', 
@object_name = N'PerformanceAnalysisDataRollup12',
@index_id = NULL,
@partition_number = NULL, 
@data_compression = N'PAGE'; 

-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisDataRollup ON dbo.PerformanceAnalysisDataRollup12 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataRollup13

-- estimate compression savings 
EXEC sys.sp_estimate_data_compression_savings 
@schema_name = N'dbo', 
@object_name = N'PerformanceAnalysisDataRollup13',
@index_id = NULL,
@partition_number = NULL, 
@data_compression = N'PAGE'; 

-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisDataRollup ON dbo.PerformanceAnalysisDataRollup13 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataRollup14

-- estimate compression savings 
EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo', 
 @object_name = N'PerformanceAnalysisDataRollup14',
 @index_id = NULL,
 @partition_number = NULL, 
 @data_compression = N'PAGE'; 

-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisDataRollup ON dbo.PerformanceAnalysisDataRollup14 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisData

-- estimate compression savings 
EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'PerformanceAnalysisData',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'PAGE';
 
-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisData_Wide ON dbo.PerformanceAnalysisData 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataDatabaseCounter

-- estimate compression savings
EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'PerformanceAnalysisDataDatabaseCounter',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'PAGE';
 
-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisData_Wide ON dbo.PerformanceAnalysisDataDatabaseCounter 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataDiskCounter

-- estimate compression savings
EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'PerformanceAnalysisDataDiskCounter',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'PAGE';
 
-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisData_Wide ON dbo.PerformanceAnalysisDataDiskCounter 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataSQLDBCounter

-- estimate compression savings
EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'PerformanceAnalysisDataSQLDBCounter',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'PAGE';
 
-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisData_Wide ON dbo.PerformanceAnalysisDataSQLDBCounter 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataTableAndIndexCounter

-- estimate compression savings
EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'PerformanceAnalysisDataTableAndIndexCounter',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'PAGE';
 
-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisData_Wide ON dbo.PerformanceAnalysisDataTableAndIndexCounter 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataTintriCounter

-- estimate compression savings
EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'PerformanceAnalysisDataTintriCounter',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'PAGE';
 
-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisData_Wide ON dbo.PerformanceAnalysisDataTintriCounter 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);

-- PerformanceAnalysisDataVMCounter

-- estimate compression savings
EXEC sys.sp_estimate_data_compression_savings 
 @schema_name = N'dbo',  
 @object_name = N'PerformanceAnalysisDataVMCounter',
 @index_id = NULL,
 @partition_number = NULL,   
 @data_compression = N'PAGE';
 
-- alter index to use page compression
ALTER INDEX IX_PerformanceAnalysisData_Wide ON dbo.PerformanceAnalysisDataVMCounter 
REBUILD PARTITION = ALL WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);
