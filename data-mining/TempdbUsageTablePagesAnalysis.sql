/*
Use results to determine the optimal minimum pages threshold (MinimumTempDbPageAllocations),
balancing visibility into tempdb session activity with required storage.

Tempdb Session Usage settings:
	SELECT MinimumTempDbPageAllocations, TempDbSessionMonitorQueryWaitTime
	FROM dbo.ApplicationSettings;
	(* All S1 Monitoring Services must be restarted after changing *)	

Output:
	PageCt				The total count of tempdb pages allocated by the session
	PageCtPctile		The page count percentile
	SumPages			The total tempdb pages allocated by sessions with this page count
	PageRows			The total row count for the tempdb page count
	RunningSumPages		Running total of tempdb pages allocated
	RunningPageRows		Running row count
	RunningSumPagesPct	% of total for running tempdb pages allocated
	RunningPageRowsPct	% of total for running row count
*/

--Restrict rows returned when many unique page counts. Adjust up/down as needed.
DECLARE @MaxRows INT = 10000;

;WITH PageCounts
AS
(
	SELECT 
		 PageCt =
				  UserObjectsAllocPageCount
				+ TaskUserObjectsAllocPageCount
				+ InternalObjectsAllocPageCount
				+ TaskInternalObjectsAllocPageCount
		,SumPages =
				  SUM(UserObjectsAllocPageCount)
				+ SUM(TaskUserObjectsAllocPageCount)
				+ SUM(InternalObjectsAllocPageCount)
				+ SUM(TaskInternalObjectsAllocPageCount)
		,PageRows = count(1)
	FROM TempDbSessionUsage WITH (NOLOCK)
	GROUP BY
		  UserObjectsAllocPageCount
		+ TaskUserObjectsAllocPageCount
		+ InternalObjectsAllocPageCount
		+ TaskInternalObjectsAllocPageCount
)
SELECT TOP (@MaxRows) *
FROM
	(
	SELECT TOP 100 PERCENT
		 NTILE(100) OVER(ORDER BY PageCt) AS PageCtPctile 
		,PageCt
		,SumPages
		,PageRows
		,SUM(SumPages) OVER(ORDER BY PageCt ROWS UNBOUNDED PRECEDING) AS RunningSumPages
		,SUM(PageRows) OVER(ORDER BY PageCt ROWS UNBOUNDED PRECEDING) AS RunningPageRows
		,CAST(CAST(SUM(SumPages) OVER(ORDER BY PageCt ROWS UNBOUNDED PRECEDING) AS FLOAT) / SUM(SumPages) OVER() AS DECIMAL(5,5)) AS RunningSumPagesPct
		,CAST(CAST(SUM(PageRows) OVER(ORDER BY PageCt ROWS UNBOUNDED PRECEDING) AS FLOAT) / SUM(PageRows) OVER() AS DECIMAL(5,5)) AS RunningPageRowsPct
	FROM PageCounts
	ORDER BY
		PageCt
	) t
ORDER BY t.PageCt;
