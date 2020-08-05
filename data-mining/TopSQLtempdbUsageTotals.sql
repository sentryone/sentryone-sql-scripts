SET TRAN ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @StartDate datetime, @EndDate datetime, @EventSourceConnectionID smallint
/* Lookup ConnectionID:
SELECT ID, ObjectName FROM EventSourceConnection WHERE ObjectName LIKE 'servername%' AND EventSourceConnectionTypeID = 'C9268009-B3F2-4398-9A04-A9BC0666B847'
*/

SELECT
	 @StartDate =					'2020-08-01 00:00:00'
	,@EndDate =						'2020-08-02 00:00:00'
	,@EventSourceConnectionID =		206;

;WITH UniqueSessions
AS
(
	SELECT
		 EventSourceConnectionID
		,SessionID
		,[HostName]
		,[ProgramName]
		,[LoginName]
		,LoginTime
		,LastID = MAX(ID)
	FROM [dbo].[TempDbSessionUsage]
	WHERE 
		[Timestamp] >= @StartDate
	AND [Timestamp] <= @EndDate
	AND EventSourceConnectionID = @EventSourceConnectionID
	GROUP BY
		 EventSourceConnectionID
		,SessionID
		,[HostName]
		,[ProgramName]
		,[LoginName]
		,LoginTime
)
,SessionUsageTotals
AS
(
	SELECT
		 us.EventSourceConnectionID
		,us.SessionID
		,us.[HostName]
		,us.[ProgramName]
		,us.[LoginName]
		,us.LoginTime
		,TotalCpuTime = u.CpuTime
		,TotalElapsedTimeMs = u.TotalElapsedTime
		,TotalLogicalReads = u.LogicalReads
		,TotalPhysicalWrites = u.Writes
		,TotalTempdbUserKB = (u.InternalObjectsAllocPageCount + u.TaskInternalObjectsAllocPageCount) * 8
		,TotalTempdbInternalKB = (u.UserObjectsAllocPageCount + u.TaskUserObjectsAllocPageCount) * 8
		,ActiveTempdbUserKB = (u.UserObjectsAllocPageCount - u.UserObjectsDeallocPageCount - u.UserObjectsDeferredDeallocPageCount
							+ u.TaskUserObjectsAllocPageCount - u.TaskUserObjectsDeallocPageCount) * 8
		,ActiveTempdbInternalKB = (u.InternalObjectsAllocPageCount - u.InternalObjectsDeallocPageCount
							+ u.TaskInternalObjectsAllocPageCount - u.TaskInternalObjectsDeallocPageCount) * 8
		,u.GrantedMemoryKB
		,u.UsedMemoryKB
		,u.MaxUsedMemoryKB
		,u.LastRequestStartTime
		,u.LastRequestEndTime
		,u.Timestamp
	FROM UniqueSessions us
	INNER JOIN [dbo].[TempDbSessionUsage] u
	  ON u.ID = us.LastID
)
,SessionUsageTotalsWithTrace
AS
(
	SELECT
		 ut.EventSourceConnectionID
		,ut.SessionID
		,td.NormalizedStartTime
		,ut.LastRequestStartTime
		,td.NormalizedEndTime
		,ut.[HostName]
		,ut.[ProgramName]
		,ut.[LoginName]
		,CASE WHEN td.EventClass = -1 THEN N'RequestCompleted' ELSE te.name END AS EventClass
		,td.ParentID
		,td.TextData
		,th.NormalizedTextData
		,td.TempdbUserKB
		,td.TempdbUserKBDealloc
		,td.TempdbInternalKB
		,td.TempdbInternalKBDealloc
		,ut.TotalTempdbUserKB
		,ut.TotalTempdbInternalKB
		,TotalTempdbKB = CASE WHEN TempdbUserKB > ut.TotalTempdbUserKB + ut.TotalTempdbInternalKB THEN TempdbUserKB ELSE ut.TotalTempdbUserKB + ut.TotalTempdbInternalKB END
		,ActiveTempdbKB = CASE WHEN ActiveTempdbUserKB < 0 THEN 0 ELSE ActiveTempdbUserKB END
						+ CASE WHEN ActiveTempdbInternalKB < 0 THEN 0 ELSE ActiveTempdbInternalKB END
		,td.Duration
		,td.CPU
		,td.Reads
		,td.Writes
		,td.GrantedMemoryKB
	FROM SessionUsageTotals ut
	JOIN PerformanceAnalysisTraceData td
	  ON ut.EventSourceConnectionID = td.EventSourceConnectionID
	 AND ut.SessionID = td.SPID
	 AND ut.LastRequestStartTime >= td.NormalizedStartTime
	 AND ut.LastRequestStartTime <= td.NormalizedEndTime
	JOIN dbo.PerformanceAnalysisTraceHash th
	  ON th.NormalizedTextMD5 = td.NormalizedTextMD5
	LEFT OUTER JOIN sys.trace_events te
	  ON td.EventClass = te.trace_event_id
	WHERE td.StartTime <= @EndDate
	  AND td.EndTime >= @StartDate
	  AND td.EventSourceConnectionID = @EventSourceConnectionID
	  AND td.EventClass IN (-1, 10, 12) --add 41 & 45 for statement events -- will cause duplicate data.
)
SELECT
	  utt.HostName
	 ,utt.ProgramName
	 ,utt.LoginName
	 ,utt.EventClass
	 ,utt.NormalizedTextData --swap with TextData for parameter values
	 ,SUM(utt.TotalTempdbKB) AS TotalTempdbKB
	 ,SUM(utt.ActiveTempdbKB) AS ActiveTempdbKB
	 ,COUNT(1) AS TotalCount
	 ,SUM(utt.Duration) AS TotalDuraion
	 ,SUM(utt.CPU) AS TotalCPU
	 ,SUM(utt.Reads) AS TotalReads
	 ,SUM(utt.Writes) AS TotalWrites
	 ,SUM(utt.GrantedMemoryKB) AS TotalGrantedMemKB
	 ,MAX(utt.LastRequestStartTime) AS LastRequestStartTime
FROM SessionUsageTotalsWithTrace utt
GROUP BY 
	  utt.HostName
	 ,utt.ProgramName
	 ,utt.LoginName
	 ,utt.EventClass
	 ,utt.NormalizedTextData --swap with TextData for parameter values
ORDER BY TotalTempdbKB DESC
