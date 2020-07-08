/*-------------------------------------------------------------------
-- 5 - Adaptive Joins
-- 
-- Summary: 
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/
USE AutoDealershipDemo
GO
SET STATISTICS IO ON
GO


-----
-- Setup
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Customer_State_Demo')
	CREATE NONCLUSTERED INDEX IX_Customer_State_Demo ON Customer (
		State
	);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesHistory_CustomerID_Demo')
	CREATE NONCLUSTERED INDEX IX_SalesHistory_CustomerID_Demo ON SalesHistory (
		CustomerID
	)
	INCLUDE (
		InventoryID, TransactionDate
	);
GO








-----
-- Introduce query we will be using
CREATE OR ALTER PROCEDURE dbo.sp_NumVehiclesSoldEachYearByState (
	@State CHAR(2) = 'IL'
)
AS 
BEGIN
	SELECT 
		Customer.State,
		YEAR(SalesHistory.TransactionDate) AS YearSold,
		COUNT(Inventory.VIN) AS VehiclesSold
	FROM dbo.Inventory
	INNER JOIN dbo.SalesHistory
		ON Inventory.InventoryID = SalesHistory.InventoryID
	INNER JOIN dbo.Customer
		ON SalesHistory.CustomerID = Customer.CustomerID
	WHERE Customer.State = @State
	GROUP BY 
		Customer.State,
		YEAR(SalesHistory.TransactionDate)
	ORDER BY 
		YEAR(SalesHistory.TransactionDate);
END
GO




-----
-- What is the distribution of customers to states?
SELECT State, COUNT(1)
FROM dbo.Customer
GROUP BY State
ORDER BY 2 DESC;
GO








-----
-- Disable Adaptive Joins first
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ADAPTIVE_JOINS = OFF;
GO


-- Re-Check Database Scoped Configurations
SELECT name, value, is_value_default
FROM sys.database_scoped_configurations
WHERE name = 'BATCH_MODE_ADAPTIVE_JOINS'
ORDER BY name;
GO








-----
-- Medium dataset
-- Ctrl-M: Turn on Actual Execution Plan
DBCC FREEPROCCACHE
GO
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'UT';
GO

-- Logical Reads:








-----
-- Small dataset
DBCC FREEPROCCACHE
GO
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'AK';
GO

-- Logical Reads:








-----
-- Large dataset
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'WI';
GO

-- Logical Reads:








-----
-- Turn on Adaptive Joins 
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ADAPTIVE_JOINS = ON;
GO




-----
-- Repeat prior examples




-----
-- Medium dataset
DBCC FREEPROCCACHE
GO
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'UT';
GO








-----
-- Small dataset
DBCC FREEPROCCACHE
GO
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'AK';
GO








-----
-- First into Cache matters
DBCC FREEPROCCACHE
GO
-- Large dataset
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'WI';
GO
-- Small dataset
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'AK';
GO

-- Logical Reads:








-----
-- Reverse Order
DBCC FREEPROCCACHE
GO
-- Small dataset
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'AK';
GO
-- Large dataset
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'WI';
GO

-- Logical Reads:








-----
-- A Different Progression
DBCC FREEPROCCACHE
GO
-- Very Large dataset
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'IL';
GO
-- Small dataset
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'AK';
GO
-- Medium dataset
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'UT';
GO
-- Large dataset
EXEC dbo.sp_NumVehiclesSoldEachYearByState 'WI';
GO

-- Logical Reads:
-- Memory Grants




-----
-- Clean-Up
--DROP INDEX Customer.IX_Customer_State_Demo;
--GO
--DROP INDEX SalesHistory.IX_SalesHistory_CustomerID_Demo;
--GO





------------------
------------------
------------------

/*
-- Move customers between states
UPDATE Customer
SET State = 'WI'
WHERE CustomerID IN (
	SELECT TOP (45) PERCENT CustomerID
	FROM dbo.Customer
	WHERE State = 'MA'
)
*/


