/*-------------------------------------------------------------------
-- 0 - Reset
-- 
-- Summary: 
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/


--------------------------------
-- Pre-execute BatchMode.sql
--------------------------------
USE AutoDealershipDemo
GO
EXEC dbo.sp_DropAllNCIs @PrintOnly = 0, @RestoreBaseNCIs = 0;
GO


-----
-- Database Scoped Configurations
SELECT name, value, is_value_default,
	CASE 
		WHEN database_scoped_configurations.value = 0
		THEN
		'ALTER DATABASE SCOPED CONFIGURATION SET ' + name + ' = ON;'
		WHEN
		database_scoped_configurations.value = 1
		THEN
		'ALTER DATABASE SCOPED CONFIGURATION SET ' + name + ' = OFF;'
	END AS Cmd
FROM sys.database_scoped_configurations
WHERE is_value_default = 0
ORDER BY name;
GO

-----
--
