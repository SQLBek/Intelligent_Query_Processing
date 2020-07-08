/*-------------------------------------------------------------------
-- 4 - Memory Grant
-- 
-- Summary: 
-- SQL Server 2019 broke one of my old demos!
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/
USE AutoDealershipDemo
GO

-----
-- Setup
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesHistory_TransactionDate_Demo')
	CREATE NONCLUSTERED INDEX IX_SalesHistory_TransactionDate_Demo ON SalesHistory (
		TransactionDate
	)
	INCLUDE (
		CustomerID, InventoryID, SellPrice
	)
GO

SET STATISTICS IO ON
SET STATISTICS TIME ON
GO
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ADAPTIVE_JOINS = OFF;
GO
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_MEMORY_GRANT_FEEDBACK = OFF;
GO
ALTER DATABASE SCOPED CONFIGURATION
SET ROW_MODE_MEMORY_GRANT_FEEDBACK = OFF;
GO


-----
-- Database Scoped Configurations
-- https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-scoped-configurations-transact-sql?view=sql-server-ver15
-- Re-Check Database Scoped Configurations
SELECT name, value, is_value_default
FROM sys.database_scoped_configurations
WHERE name IN ('ROW_MODE_MEMORY_GRANT_FEEDBACK', 'BATCH_MODE_MEMORY_GRANT_FEEDBACK')
ORDER BY name;
GO









-----
-- Test query
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 
	YEAR(SalesHistory.TransactionDate) AS YearSold,
	COUNT(Inventory.VIN) AS NumVehiclesSold,
	AVG(SalesHistory.SellPrice) AS AvgSellPrice1
FROM dbo.Inventory
INNER JOIN dbo.SalesHistory
	ON Inventory.InventoryID = SalesHistory.InventoryID
INNER JOIN dbo.Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
GROUP BY YEAR(TransactionDate)
ORDER BY YEAR(TransactionDate);
GO

-- Memory Grant:








-----
-- Turn on memory grant feedback
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_MEMORY_GRANT_FEEDBACK = ON;
GO
ALTER DATABASE SCOPED CONFIGURATION
SET ROW_MODE_MEMORY_GRANT_FEEDBACK = ON;
GO








-----
-- Re-run Test query
SELECT 
	YEAR(SalesHistory.TransactionDate) AS YearSold,
	COUNT(Inventory.VIN) AS NumVehiclesSold,
	AVG(SalesHistory.SellPrice) AS AvgSellPrice1
FROM dbo.Inventory
INNER JOIN dbo.SalesHistory
	ON Inventory.InventoryID = SalesHistory.InventoryID
INNER JOIN dbo.Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
GROUP BY YEAR(TransactionDate)
ORDER BY YEAR(TransactionDate);
GO

-- Memory Grant:








-----
-- Run with varied values
CREATE OR ALTER PROCEDURE dbo.sp_GetSalesSummaryByYear (
	@StartDate DATETIME = '2010-01-01', 
	@EndDate DATETIME = '2020-01-01'
)
AS 
BEGIN
	SELECT 
		YEAR(SalesHistory.TransactionDate) AS YearSold,
		COUNT(Inventory.VIN) AS NumVehiclesSold,
		AVG(SalesHistory.SellPrice) AS AvgSellPrice1
	FROM dbo.Inventory
	INNER JOIN dbo.SalesHistory
		ON Inventory.InventoryID = SalesHistory.InventoryID
	INNER JOIN dbo.Customer
		ON SalesHistory.CustomerID = Customer.CustomerID
	WHERE SalesHistory.TransactionDate >= @StartDate 
		AND SalesHistory.TransactionDate < @EndDate
	GROUP BY YEAR(SalesHistory.TransactionDate)
	ORDER BY YEAR(SalesHistory.TransactionDate);
END
GO








-----
-- First run
DBCC FREEPROCCACHE;
GO

EXEC dbo.sp_GetSalesSummaryByYear '2019-01-01', '2020-01-01';
GO

EXEC dbo.sp_GetSalesSummaryByYear '2017-01-01', '2020-01-01';
GO

EXEC dbo.sp_GetSalesSummaryByYear '2013-01-01', '2020-01-01';
GO

-- Memory Grant:




-- Problem here?









-----
-- Reverse order: Large to small
DBCC FREEPROCCACHE;
GO

EXEC dbo.sp_GetSalesSummaryByYear '2013-01-01', '2020-01-01';
GO

EXEC dbo.sp_GetSalesSummaryByYear '2017-01-01', '2020-01-01';
GO

EXEC dbo.sp_GetSalesSummaryByYear '2019-01-01', '2020-01-01';
GO

-- Memory Grant:




-----
-- IsMemoryGrantFeedbackAdjusted Key
--
-- 1. No: First Execution
-- Memory grant feedback does not adjust memory for the first compile and associated execution.
--
-- 2. No: Accurate Grant
-- If there is no spill to disk and the statement uses at least 50% of the granted memory, then memory grant feedback is not triggered.
--
-- 3. Yes: Adjusting
-- Memory grant feedback has been applied and may be further adjusted for the next execution.
--
-- 4. Yes: Stable
-- Memory grant feedback has been applied and granted memory is now stable, meaning that what was last granted for the previous execution is what was granted for the current execution.
--
-- 5. No: Feedback disabled
-- If memory grant feedback is continually triggered and fluctuates between memory-increase and memory-decrease operations, we will disable memory grant feedback for the statement.
--
--

-----
-- NOTE:
-- For parameter-sensitive plans, memory grant feedback will disable itself on a query if it has unstable memory requirements.
-- Source: https://docs.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing?view=sql-server-ver15#batch-mode-memory-grant-feedback


-----
-- Clean-Up
--DROP INDEX SalesHistory.IX_SalesHistory_TransactionDate_Demo
--GO
