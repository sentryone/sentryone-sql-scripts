# sentryone-sql-scripts
SQL scripts for the SentryOne database. Use caution when running these scripts to ensure that you understand the updates that will be applied. It's recommended that you have the proper database backups before applying updates, and test them in a test environment before production.

## **scalability-pack-updates**

### AdvisoryConditionEvalTrackingSchema-MovePABufferData.sql
https://www.sentryone.com/blog/charting-custom-counters-in-sentryone

### AdvisoryConditionEvalTrackingSchema.sql
https://www.sentryone.com/blog/charting-custom-counters-in-sentryone

### ConvertToMO_DynamicConditionStatus.sql
https://www.sentryone.com/blog/charting-custom-counters-in-sentryone

### GetPerfDataTableUsagePct.sql
See https://www.sentryone.com/blog/enabling-higher-resolution-performance-charts-in-sentryone

### S1PerfDataResolutionAndRetention.xlsx
See https://www.sentryone.com/blog/enabling-higher-resolution-performance-charts-in-sentryone

## **sentryone-administration-scripts**

### ActionsEmailUpdateRecipientToGroup.sql
- Updates the email address used in Action Settings from a single user recipient to a group
