/*-------------------------------------------------------------------
-- 1b - Table Variables: Pitfall
-- 
-- Summary: 
-- Thanks Brent Ozar
-- https://www.brentozar.com/archive/2018/09/sql-server-2019-faster-table-variables-and-new-parameter-sniffing-issues/
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/
USE AutoDealershipDemo
GO
SET STATISTICS IO ON
SET STATISTICS TIME ON
GO
DBCC FREEPROCCACHE
GO








-----
-- Procedure that uses a Table Variable
CREATE OR ALTER PROCEDURE dbo.sp_Customer_TblVar
	@Count INT = 3	-- Controls # of CustomerIDs inserted into @Customer
AS
BEGIN
	-- Create table variable
	DECLARE @Customer TABLE (
		CustomerID INT INDEX CX_CustomerID CLUSTERED
	);

	-- Insert 1 record into Table Variable
	INSERT INTO @Customer
	SELECT TOP(@Count)
		CustomerID
	FROM dbo.Customer

	-- Compare
	PRINT '-- Table Variable --';
	SELECT 'Table Variable', 
		SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID
	FROM dbo.SalesHistory
	INNER JOIN @Customer AS Customer
		ON SalesHistory.CustomerID = Customer.CustomerID
END
GO

-----
-- Need a covering index as well
CREATE NONCLUSTERED INDEX IX_SalesHistory_CustomerID_Demo ON dbo.SalesHistory (
	CustomerID	
);
GO








-----
-- Turn OFF DEFERRED_COMPILATION_TV
ALTER DATABASE SCOPED CONFIGURATION
SET DEFERRED_COMPILATION_TV = OFF;
GO

-- Re-Check Database Scoped Configurations
SELECT name, value, is_value_default
FROM sys.database_scoped_configurations
WHERE name = 'DEFERRED_COMPILATION_TV'
ORDER BY name;
GO








-----
-- Ctrl-M: Turn on Actual Execution Plan
EXEC dbo.sp_Customer_TblVar @Count = 3;
GO


EXEC dbo.sp_Customer_TblVar @Count = 300000;
GO








-----
-- Turn OFF DEFERRED_COMPILATION_TV
ALTER DATABASE SCOPED CONFIGURATION
SET DEFERRED_COMPILATION_TV = ON;
GO
DBCC FREEPROCCACHE
GO




EXEC dbo.sp_Customer_TblVar @Count = 5;
GO


EXEC dbo.sp_Customer_TblVar @Count = 300000;
GO








-----
-- RESET
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ADAPTIVE_JOINS = ON;
GO
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ON_ROWSTORE = ON;
GO
ALTER DATABASE SCOPED CONFIGURATION
SET DEFERRED_COMPILATION_TV = ON;
GO


--------------
-------------
-------------
