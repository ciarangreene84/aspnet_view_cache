USE [Northwind]
GO

/****** Object:  StoredProcedure [dbo].[AspNet_SqlCacheRegisterViewStoredProcedure]    Script Date: 07/12/2018 15:00:45 ******/
IF (OBJECT_ID('AspNet_SqlCacheRegisterViewStoredProcedure') IS NOT NULL)
DROP PROCEDURE [dbo].[AspNet_SqlCacheRegisterViewStoredProcedure]
GO

/****** Object:  StoredProcedure [dbo].[AspNet_SqlCacheRegisterViewStoredProcedure]    Script Date: 07/12/2018 15:00:45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[AspNet_SqlCacheRegisterViewStoredProcedure] 
	@viewName NVARCHAR(450) 
AS
BEGIN

	-- check if view
	/* First make sure the table exists */ 
	IF (SELECT OBJECT_ID(@viewName, 'V')) IS NULL 
	BEGIN 
		RAISERROR ('00000001', 16, 1) 
		RETURN 
	END 

	BEGIN TRAN

	/* Insert the value into the notification table */ 
	IF NOT EXISTS (SELECT tableName FROM dbo.AspNet_SqlCacheTablesForChangeNotification WITH (NOLOCK) WHERE tableName = @viewName) 
		IF NOT EXISTS (SELECT tableName FROM dbo.AspNet_SqlCacheTablesForChangeNotification WITH (TABLOCKX) WHERE tableName = @viewName) 
			INSERT  dbo.AspNet_SqlCacheTablesForChangeNotification 
			VALUES (@viewName, GETDATE(), 0)

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
		DECLARE @canonTableName NVARCHAR(3000) 
		DECLARE @quotedViewName NVARCHAR(3000) 

		/* Create the trigger name */ 
		SET @triggerName = REPLACE(@tableName, '[', '__o__') 
		SET @triggerName = REPLACE(@triggerName, ']', '__c__') 
		SET @triggerName = @triggerName + '_AspNet_SqlCacheNotification_Trigger' 
		SET @fullTriggerName = 'dbo.[' + @viewName + '_' + @triggerName + ']' 

		/* Create the cannonicalized table name for trigger creation */ 
		/* Do not touch it if the name contains other delimiters */ 
		IF (CHARINDEX('.', @tableName) <> 0 OR 
			CHARINDEX('[', @tableName) <> 0 OR 
			CHARINDEX(']', @tableName) <> 0) 
			SET @canonTableName = @tableName 
		ELSE 
			SET @canonTableName = '[' + @tableName + ']' 

		SET @quotedViewName = QUOTENAME(@viewName, '''') 
		IF NOT EXISTS (SELECT name FROM sysobjects WITH (NOLOCK) WHERE name = @triggerName AND type = 'TR') 
			IF NOT EXISTS (SELECT name FROM sysobjects WITH (TABLOCKX) WHERE name = @triggerName AND type = 'TR') 
				EXEC ('CREATE TRIGGER ' + @fullTriggerName + ' ON ' + @canonTableName +'
					FOR INSERT, UPDATE, DELETE AS BEGIN
					SET NOCOUNT ON
					EXEC dbo.AspNet_SqlCacheUpdateChangeIdStoredProcedure N' + @quotedViewName + '
					END
					');

		FETCH NEXT FROM table_cursor INTO @tableName;  
	END

	CLOSE table_cursor;
	DEALLOCATE table_cursor;

	COMMIT TRAN

END
   
GO


