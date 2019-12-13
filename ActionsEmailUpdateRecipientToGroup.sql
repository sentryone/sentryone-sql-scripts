/*

ReadMe

Caution: These scripts perform updates against the SentryOne database. Update the values where appropriate for your data.

Purpose: Updates the email address used in Action Settings from a single user recipient to a group

*/

--Enter the First and Last name of the User that the Group will replace
DECLARE @ContactToReplace AS INTEGER = (SELECT ID
FROM Contact
WHERE FirstName = 'Patrick' AND LastName = 'Kelley')

--Enter the name of the Group to replace the User
DECLARE @GroupToAdd AS INTEGER = (SELECT ID
FROM ContactGroup
WHERE GroupName = 'DBA')

DECLARE @ConditionID INT
DECLARE @ConditionsCursor CURSOR

SET @ConditionsCursor = CURSOR FOR
SELECT ObjectConditionActionID FROM ObjectActionContacts
WHERE ContactID = @ContactToReplace

OPEN @ConditionsCursor
FETCH NEXT FROM @ConditionsCursor INTO @ConditionID
WHILE @@FETCH_STATUS = 0
BEGIN
	IF NOT EXISTS(SELECT ObjectConditionActionID, ContactGroupID FROM ObjectActionContactGroups WHERE ObjectConditionActionID = @ConditionID AND ContactGroupID = @GroupToAdd)
	INSERT INTO ObjectActionContactGroups VALUES (@ConditionID, @GroupToAdd)
	FETCH NEXT FROM @ConditionsCursor INTO @ConditionID
END

CLOSE @ConditionsCursor
DEALLOCATE @ConditionsCursor

--[OPTIONAL] Remove the User from email alerts
DELETE FROM ObjectActionContacts
WHERE ContactID = @ContactToReplace
