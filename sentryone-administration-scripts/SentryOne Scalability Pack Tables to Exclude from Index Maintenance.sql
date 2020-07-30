/*
This script selects a list of tables from the SentryOne database that should be excluded from index maintenance type jobs.
It is only used for SentryOne databases that have the scalability pack applied.
See https://docs.sentryone.com/help/github-advisory-conditions#s1-team-submitted-scalability-pack and https://docs.sentryone.com/help/recommendations#apply-the-sentryone-scalability-pack-for-more-than-250-targets
*/
SELECT
SchemaName = s.[name],
ObjectName = o.[Name],
IndexName = i.[name],
IndexDesc = i.type_desc
FROM sys.indexes i
JOIN sys.objects o
ON i.object_id = o.object_id
JOIN sys.schemas s
ON o.schema_id = s.schema_id
WHERE i.type = 5
OR (s.[name] = 'Staging' AND i.type > 0)
ORDER BY SchemaName, ObjectName;