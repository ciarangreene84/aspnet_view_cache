USE [Northwind]
GO

/****** Object:  StoredProcedure [dbo].[AspNet_SqlCacheUnRegisterViewStoredProcedure]    Script Date: 07/12/2018 15:03:02 ******/
IF (OBJECT_ID('AspNet_SqlCacheUnRegisterViewStoredProcedure') IS NOT NULL)
DROP PROCEDURE [dbo].[AspNet_SqlCacheUnRegisterViewStoredProcedure]
GO

/****** Object:  StoredProcedure [dbo].[AspNet_SqlCacheUnRegisterViewStoredProcedure]    Script Date: 07/12/2018 15:03:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[AspNet_SqlCacheUnRegisterViewStoredProcedure] 
	@viewName NVARCHAR(450) 
AS
BEGIN

	-- check if view
	/* First make sure the view exists */ 
	IF (SELECT OBJECT_ID(@viewName, 'V')) IS NULL 
	BEGIN 
		RAISERROR ('00000001', 16, 1) 
		RETURN 
	END 

	BEGIN TRAN

    /* Remove the table-row from the notification table */ 
    IF EXISTS (SELECT name FROM sysobjects WITH (NOLOCK) WHERE name = 'AspNet_SqlCacheTablesForChangeNotification' AND type = 'U') 
        IF EXISTS (SELECT name FROM sysobjects WITH (TABLOCKX) WHERE name = 'AspNet_SqlCacheTablesForChangeNotification' AND type = 'U') 
			DELETE FROM dbo.AspNet_SqlCacheTablesForChangeNotification WHERE tableName = @viewName 

	DECLARE table_cursor CURSOR FOR 
		SELECT DISTINCT referenced_entity_name 
			FROM sys.dm_sql_referenced_entities('dbo.[' + @viewName + ']','Object') refs
			INNER JOIN sys.objects
					ON refs.referenced_id = objects.object_id
				   AND objects.type = 'U';
	OPEN table_cursor  

	DECLARE @tableName NVARCHAR(450) 
	FETCH NEXT FROM table_cursor INTO @tableName;  
	WHILE @@FETCH_STATUS = 0  
	BEGIN 
		DECLARE @triggerName AS NVARCHAR(3000) 
		DECLARE @fullTriggerName AS NVARCHAR(3000)

		/* Create the trigger name */ 
		SET @triggerName = REPLACE(@tableName, '[', '__o__') 
		SET @triggerName = REPLACE(@triggerName, ']', '__c__') 
		SET @triggerName = @viewName + '_' + @triggerName + '_AspNet_SqlCacheNotification_Trigger' 
		SET @fullTriggerName = 'dbo.[' + @triggerName + ']' 

         /* Remove the trigger */ 
         IF EXISTS (SELECT name FROM sysobjects WITH (NOLOCK) WHERE name = @triggerName AND type = 'TR') 
             IF EXISTS (SELECT name FROM sysobjects WITH (TABLOCKX) WHERE name = @triggerName AND type = 'TR') 
             EXEC ('DROP TRIGGER ' + @fullTriggerName);

		FETCH NEXT FROM table_cursor INTO @tableName;  
	END

	CLOSE table_cursor;
	DEALLOCATE table_cursor;

	COMMIT TRAN

END
   
GO


