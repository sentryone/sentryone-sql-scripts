Use SentryOne;  -- Update to the proper name of the S1 Repository

/*** Check for existance of the Temp Table, drop table if it exists ***/
IF OBJECT_ID('tempdb..#MoveList') IS NOT NULL
    DROP TABLE #MoveList;
GO

CREATE Table #MoveList (
        HostName varchar(128) NOT NULL,
        DeviceID smallint)

/*********************************************************************************************************************
*  Use the script below to load a server or list of servers into a temp table that will be moved into a new Group.
*  The servers do not have to currently belong to the same site or group.
*  If a single server is being moved, set the @HostName variable for the servername.
*  If there are several servers with the same naming convention, use the @HostNameLike.
*  If you have a list of servers, you may populate the #MoveList table independently or by building a sub-select
*  to use in the last UNION statement on line 54.
*  The DEVICE table contains the information for each Connection and which group is directly above it in the Navigator.
*
*  The Navigator Pane may not refresh to reflect the changes, you may need to close and re-open the S1 Client.
***********************************************************************************************************************/
DECLARE @DestinationGroupName   NVARCHAR(128) = 'TestG1', 
        @DestinationGroupID     UNIQUEIDENTIFIER,
        @SiteID                 INT,
        @ParentSiteObjectID     UNIQUEIDENTIFIER,
        @ManagementEngineID     INT,
        @HostName               NVARCHAR(128) = '',           -- Provide a single specific HostName
        @HostNameLike           NVARCHAR(128) = '%VM-PROSRV-1%'  -- Provide a string to search for devices that match the HostName

SELECT @DestinationGroupID = OBJECTID  FROM Site 
WHERE Name = @DestinationGroupName;

/** Check if the New Group Name exists **/
IF @DestinationGroupID IS NULL
  BEGIN
    RAISERROR ('Supplied @DestinationGroupName does not exist. Please check for the correct Name in the DEVICE table and try again.', 18, 1)
    RETURN
  END;
  
/********** Gather the correct SiteID, not the SiteID for the Group or SubGroup ************/

/** First level SiteID **/
SELECT @SiteID = ID, @ParentSiteObjectID = ParentSiteObjectID FROM Site WHERE ObjectID = @DestinationGroupID

/**** Loop through Site table to gather the correct SiteID if the Destination Group is not a SITE  ****/
WHILE @ParentSiteObjectID IS NOT NULL
BEGIN
    SELECT @SiteID = ID, @ParentSiteObjectID = ParentSiteObjectID FROM Site WHERE ObjectID = @ParentSiteObjectID
END 

/** Get the correct ManagementEngineID if one exists **/
SELECT @ManagementEngineID = ID FROM ManagementEngine WHERE SiteID = @SiteID

/************ Build holding table for Targets to be moved *********************/

/**  Set blank/unused variables to NULL so the INSERT will run properly  **/
IF @HostName = ''  SET @HostName = NULL; 
IF @HostNameLike = '%%'  SET @HostNameLike = NULL; 

/*** Insert list of Computers to move into a new Group/Site ***/
INSERT INTO #MoveList
SELECT HostName, ID FROM Device
WHERE DeviceTypeID = 'AFAB5924-2BD6-4D9A-86B6-E309685EC057' -- WINDOWS COMPUTER Device Type
      AND HostName = @HostName
UNION
SELECT HostName, ID FROM Device
WHERE DeviceTypeID = 'AFAB5924-2BD6-4D9A-86B6-E309685EC057' -- WINDOWS COMPUTER Device Type
      AND HostName LIKE @HostNameLike
UNION
SELECT HostName, ID FROM Device
WHERE DeviceTypeID = 'AFAB5924-2BD6-4D9A-86B6-E309685EC057' -- WINDOWS COMPUTER Device Type
      AND HostName in ('');  -- Enter a list of hosts or create a subquery

      
/** List all objects moved include old site/group and new site/group, can be commented out **/ 
select S.Name AS 'Old Site\Group Name', ML.HostName, @DestinationGroupName AS 'New Site\Group Name' from #MoveList ML
INNER JOIN Device D on ML.DeviceID = D.ID
INNER JOIN Site S on D.ParentSiteObjectID = S.ObjectID;


UPDATE Device
SET ParentSiteObjectID = @DestinationGroupID, -- ObjectID from Site table for the Destination Group
    SiteID = @SiteID,                         -- SiteID for the Site the Destination Group belongs to
    ManagementEngineID = @ManagementEngineID  -- management engine ID for the Site, Can be NULL
WHERE ID in (SELECT DeviceID FROM #MoveList); -- Device IDs