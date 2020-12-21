/*
  https://docs.sentryone.com/help/enabling-extended-events
*/

--Disable old xe trace, if exists and enabled
IF EXISTS
(
SELECT * FROM dbo.FeatureFlag
WHERE [Name] = 'XeventsTrace' and [Enabled] = 1
)
UPDATE dbo.FeatureFlag
SET [Enabled] = 0
WHERE [Name] = 'XeventsTrace';
--Enable RingBuffer XE trace
IF NOT EXISTS
(
SELECT * FROM dbo.FeatureFlag
WHERE [Name] = 'XEventsRingBuffer'
)
INSERT INTO dbo.FeatureFlag ([Name], [Enabled])
VALUES ( 'XEventsRingBuffer', 1);

SELECT * FROM dbo.FeatureFlag;
