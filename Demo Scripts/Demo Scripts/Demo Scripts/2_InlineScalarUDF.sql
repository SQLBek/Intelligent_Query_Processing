/*-------------------------------------------------------------------
-- 2 - Inline Scalar User Defined Functions
-- 
-- Summary: 
-- SQL Server 2019 broke one of my old demos!
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/
USE AutoDealershipDemo
GO
SET STATISTICS IO ON
SET STATISTICS TIME ON
GO
ALTER DATABASE SCOPED CONFIGURATION
SET TSQL_SCALAR_UDF_INLINING = OFF;
GO

CREATE NONCLUSTERED INDEX IX_SalesHistory_InventoryID_Demo
	ON dbo.SalesHistory (InventoryID)
	INCLUDE (SalesPersonID, SellPrice);
GO

CREATE NONCLUSTERED INDEX IX_Inventory_VIN_Demo
	ON dbo.Inventory (VIN)
	INCLUDE (InvoicePrice);
GO





-----
-- Scalar User Defined Functions (UDFs)
SELECT TOP 20000
	Inventory.InventoryID,
	Inventory.VIN,
	dbo.udf_CalcNetProfit(Inventory.VIN) AS NetProfit,
	dbo.udf_CalcSalesCommission(Inventory.VIN) AS CommissionPaid
FROM dbo.Inventory
INNER JOIN SalesHistory
	ON SalesHistory.InventoryID = Inventory.InventoryID;
GO

-- Logical Reads:
-- SQL Server Execution Times:

-- Ctrl-L: Show estimated execution plan









-----
-- sys.dm_exec_function_stats
-- SQL SERVER 2016 & higher
SELECT OBJECT_NAME(object_id) AS function_name,
	type_desc,
	execution_count,
	total_logical_reads,
	-- last_logical_reads, min_logical_reads, max_logical_reads
	total_worker_time,
	-- last_worker_time, min_worker_time, max_worker_time,
	total_elapsed_time,
	-- last_elapsed_time, min_elapsed_time, max_elapsed_time
	cached_time
FROM sys.dm_exec_function_stats
WHERE object_name(object_id) IS NOT NULL;
GO








-----
-- What does inlining mean?
-- Refer back to prior estimated execution plan
-- Ctrl-L: Show estimated execution plan
SELECT TOP 20000
	Inventory.InventoryID,
	Inventory.VIN,
	dbo.udf_CalcNetProfit(Inventory.VIN) AS NetProfit,
	dbo.udf_CalcSalesCommission(Inventory.VIN) AS CommissionPaid
FROM dbo.Inventory
INNER JOIN SalesHistory
	ON SalesHistory.InventoryID = Inventory.InventoryID;
GO








-----
-- Database Scoped Configurations
-- https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-scoped-configurations-transact-sql?view=sql-server-ver15
-- Re-Check Database Scoped Configurations
SELECT name, value, is_value_default
FROM sys.database_scoped_configurations
WHERE name = 'TSQL_SCALAR_UDF_INLINING'
ORDER BY name;
GO








-----
-- Turn on T-SQL Scalar UDF Inlining
ALTER DATABASE SCOPED CONFIGURATION
SET TSQL_SCALAR_UDF_INLINING = ON;
GO









-----
-- Scalar User Defined Functions (UDFs)
SELECT TOP 20000
	Inventory.InventoryID,
	Inventory.VIN,
	dbo.udf_CalcNetProfit(Inventory.VIN) AS NetProfit,
	dbo.udf_CalcSalesCommission(Inventory.VIN) AS CommissionPaid
FROM dbo.Inventory
INNER JOIN SalesHistory
	ON SalesHistory.InventoryID = Inventory.InventoryID;
GO
-- Logical Reads:
-- SQL Server Execution Times:

-- Ctrl-L: Show estimated execution plan




-----
-- What is inlineable?
-- Check sql_modules
SELECT 
	OBJECT_NAME(sql_modules.object_id) AS object_name,
	inline_type,	-- is inlining turned on or off
	is_inlineable
FROM sys.sql_modules
WHERE object_id = OBJECT_ID(N'udf_CalcNetProfit')
	OR object_id = OBJECT_ID(N'udf_CalcSalesCommission');
GO


-- Source: https://docs.microsoft.com/en-us/sql/relational-databases/user-defined-functions/scalar-udf-inlining?view=sql-server-ver15#inlineable-scalar-udfs-requirements







-----
-- Flattened Query for comparison
-- Ctrl-M: Turn on Actual Execution Plan
PRINT '-- Flattened Query --';

SELECT TOP 20000
	Inventory.InventoryID,
	Inventory.VIN,
	SalesHistory.SellPrice - Inventory.InvoicePrice AS NetProfit,
	CASE 
		WHEN (SalesHistory.SellPrice - Inventory.InvoicePrice) * SalesPerson.CommissionRate < 0
			THEN 0
		ELSE
			(SalesHistory.SellPrice - Inventory.InvoicePrice) * SalesPerson.CommissionRate
	END AS CommissionPaid
FROM dbo.Inventory
INNER JOIN SalesHistory
	ON SalesHistory.InventoryID = Inventory.InventoryID
	INNER JOIN dbo.SalesPerson
		ON SalesHistory.SalesPersonID = SalesPerson.SalesPersonID;
GO
-- Logical Reads:
-- SQL Server Execution Times:

PRINT '-- Inlined UDF --';

SELECT TOP 20000
	Inventory.InventoryID,
	Inventory.VIN,
	dbo.udf_CalcNetProfit(Inventory.VIN) AS NetProfit,
	dbo.udf_CalcSalesCommission(Inventory.VIN) AS CommissionPaid
FROM dbo.Inventory
INNER JOIN SalesHistory
	ON SalesHistory.InventoryID = Inventory.InventoryID;
GO
-- Logical Reads:
-- SQL Server Execution Times:


-- Which was faster or slower?  Why? 
-- Check exec plan operators: SELECT & an Index Operator








-----
-- Parallelism, Batch/Row, each UDF independently inlined, not combined!



-----
-- BONUS
ALTER DATABASE SCOPED CONFIGURATION
SET TSQL_SCALAR_UDF_INLINING = OFF;
GO


DROP TABLE IF EXISTS #outputOne;
GO
SELECT 
	AVG(CAST(SalesHistory.SalesHistoryID AS BIGINT)) AS SalesHistoryIDAvg, 
	AVG(CAST(SalesHistory.CustomerID AS BIGINT)) AS CustomerID,  
	AVG(CAST(Customer.CustomerID AS BIGINT)) AS CustID2,
	dbo.udf_CalcNetProfit(Inventory.VIN) AS NetProfit,
	AVG(SalesHistory.SellPrice) AS AvgSellPrice
INTO #outputOne
FROM dbo.SalesHistory AS SalesHistory
INNER JOIN dbo.Customer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
INNER JOIN dbo.Inventory
	ON SalesHistory.InventoryID = Inventory.InventoryID
GO


-----
-- Turn UDF Inlining back on & re-run above
ALTER DATABASE SCOPED CONFIGURATION
SET TSQL_SCALAR_UDF_INLINING = ON;
GO