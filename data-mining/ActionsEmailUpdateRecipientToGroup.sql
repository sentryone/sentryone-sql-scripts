/*

ReadMe

Caution: These scripts perform updates against the SentryOne database. Update the values where appropriate for your data.

Purpose: Updates the email address used in Action Settings from a single user recipient to a group

*/

USE SentryOne;
GO

--Enter the First and Last name of the User that the Group will replace
DECLARE @ContactToReplace AS INTEGER = 
	(SELECT ID FROM dbo.Contact WHERE FirstName = 'FName' AND LastName = 'LName')
	
--Enter the name of the Group to replace the User
DECLARE @GroupToAdd AS INTEGER = 
	(SELECT ID FROM dbo.ContactGroup WHERE GroupName = 'GroupName')
	
--Add Group to Send Email Action for Conditions sending emails to chosen Contact
;WITH Conditions AS (
	SELECT 
		c.ObjectConditionActionID, GroupID=@GroupToAdd
	FROM dbo.ObjectActionContacts c
	JOIN dbo.ObjectConditionAction a ON c.ObjectConditionActionID = a.ID
	WHERE a.ActionTypeID = 'B08B4C03-414D-41E8-AA5D-10865C6F95F3'
	  AND c.ContactID = @ContactToReplace
	  AND c.ObjectConditionActionID NOT IN
		(SELECT ObjectConditionActionID FROM dbo.ObjectActionContactGroups
		 WHERE ContactGroupID = @GroupToAdd)
	)
INSERT INTO dbo.ObjectActionContactGroups (ObjectConditionActionID,ContactGroupID)
	SELECT ObjectConditionActionID, GroupID FROM Conditions;
	
--Remove Contact from Send Email Action for same Conditions as above
DELETE c
FROM dbo.ObjectActionContacts c
JOIN dbo.ObjectConditionAction a ON c.ObjectConditionActionID = a.ID
WHERE a.ActionTypeID = 'B08B4C03-414D-41E8-AA5D-10865C6F95F3'
  AND c.ContactID = @ContactToReplace;
  
--Verify Results
SELECT 'Number of Conditions configured to send email to Contact ' + 
	FirstName +' '+LastName FROM dbo.Contact WHERE ID = @ContactToReplace;
SELECT COUNT(*) FROM dbo.ObjectActionContacts
WHERE ContactID = @ContactToReplace;

SELECT 'Number of Conditions configured to send email to Group ' + 
	GroupName FROM dbo.ContactGroup WHERE ID = @GroupToAdd;
SELECT COUNT(*) FROM dbo.ObjectActionContactGroups
WHERE ContactGroupID = @GroupToAdd;
