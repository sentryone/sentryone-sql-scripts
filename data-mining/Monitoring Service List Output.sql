/*************************************************************************************************
   Query to return the "Show Monitoring Service List" Globally
**************************************************************************************************/



SELECT          S.NAME                                     AS [Site]
                , ME.ServerName                            AS [Monitoring Service]
                , MAX(ME.ServiceAccountName)               AS [Service Account]
                , COUNT(DISTINCT( D.ID ))                  AS [Number of Monitored Targets]
                , MAX(ME.OsAvailableMemory)  / 1024 / 1024 AS [Physical Memory]
                , MAX(ME.OsAvailableMemory)  / 1024 / 1024 AS [Available Memory]
                , MAX(ME.ServiceMemoryInUse) / 1024 / 1024 AS [Service Memory Used (MB)]
                , MAX(ME.HeartbeatDateTime)                AS [Last Heartbeat]
FROM            SentryOne.dbo.ManagementEngine ME
INNER JOIN      SentryOne.dbo.Device D ON D.ManagementEngineID = ME.ID
INNER JOIN      SentryOne.dbo.Site S ON S.ID = ME.SiteID
                                        AND S.ID = D.SiteID
LEFT OUTER JOIN SentryOne.dbo.EventSourceConnection ESC WITH (NOLOCK) ON ESC.DeviceID = D.ID
WHERE           D.IsPerformanceAnalysisEnabled = Cast(1 AS BIT)
                 OR ESC.IsWatched = Cast(1 AS BIT)
                 OR ESC.IsPerformanceAnalysisEnabled = Cast(1 AS BIT)
GROUP           BY S.NAME
                   , ME.ServerName; 


