/*** Script to periodically update "secondary" column stats for all partitioned CCI tables ***

BACKGROUND:
	As part of the Scalability Pack install, auto-stats are disabled for all non-Timestamp columns in the partitioned CCI tables. This eliminates
	ongoing overhead from updating these stats, since although considered by the optimizer, they rarely impact query plan selection. However, in
	extreme cases, stale stats for these columns can cause queries to use row mode vs batch mode which will cause poor query performance. Updating
	these stats monthly should be sufficient for most systems, but also update whenever a large number of monitored targets are added or removed.

IMPORTANT:
	- The SentryOne Scalability Pack must be installed first (partitioned CCI + In-mem OLTP)
	  https://docs.sentryone.com/help/recommendations#scalabilitypack
	- Full stats updates on CCI table columns must decompress all data in the columns in order to sample the data. This will consume additional
	  non-buffer memory which may cause significant memory pressure, especially when larger tables are involved. As this may take a long time
	  and impact performance, it's highly recommended to schedule the updates during a low period maintenance window.
*/

SET NOCOUNT ON;

DECLARE @TheTSQL nvarchar(max);

BEGIN
	PRINT 'Stats update process starting...';
END

DECLARE curDisableStats CURSOR FOR
	select
		'UPDATE STATISTICS ' + object_name(st.object_id)  + ' (' + st.name + ') WITH INCREMENTAL = OFF'
	from sys.stats st
	join sys.stats_columns sc
		on st.object_id = sc.object_id
		and st.stats_id = sc.stats_id
	join sys.columns c
		on sc.object_id = c.object_id
		and sc.column_id = c.column_id
	cross apply sys.dm_db_stats_properties(st.object_id, st.stats_id)
	where object_name(st.object_id) like 'PerformanceAnalysisData%'
		and object_name(st.object_id) not like '%temp%'
		and st.stats_id > 1
		and c.name IN
		(
			 'PerformanceAnalysisCounterID'
			,'DeviceID'
			,'EventSourceConnectionID'
			,'InstanceName'
		)
	order by object_name(st.object_id);
OPEN curDisableStats;
FETCH NEXT FROM curDisableStats INTO @TheTSQL;
WHILE @@FETCH_STATUS = 0
BEGIN
	BEGIN
		PRINT '@TheTSQL: ' + @TheTSQL;
	END
	EXEC sp_executesql @TheTSQL
    FETCH NEXT FROM curDisableStats INTO @TheTSQL;
END;
CLOSE curDisableStats;
DEALLOCATE curDisableStats;

BEGIN
	PRINT 'update secondary stats process complete.';
END


--We must disable autostats again since they are reenabled by the update.
EXEC Partitioning.DisableAutoStats 0;