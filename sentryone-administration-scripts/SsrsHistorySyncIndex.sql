/*
This index supports the SentryOne SSRS history sync process, and may be required when there are high rows in the ExecutionLogStorage table,
causing the S1 sync query to run long and impact resources on the target.

Run the script in the context of the associated ReportServer database.

*** This script is provided as-is with no warranties. Use at your own risk. ***
*/

CREATE INDEX [IX_SentryOne_HistorySync]
ON [dbo].[ExecutionLogStorage]
	([ReportID] ASC, [TimeStart] ASC)
INCLUDE ([ReportAction])
GO
