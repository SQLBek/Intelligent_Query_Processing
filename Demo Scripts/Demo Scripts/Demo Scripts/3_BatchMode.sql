/*-------------------------------------------------------------------
-- 3 - Batch Mode
-- 
-- Summary: Introducing Batch Mode
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/
USE AutoDealershipDemo
GO


-----
-- Setup
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ON_ROWSTORE = OFF;
GO
SET STATISTICS IO ON
SET STATISTICS TIME ON
GO


-- Re-Check Database Scoped Configurations
SELECT name, value, is_value_default
FROM sys.database_scoped_configurations
WHERE name = 'BATCH_MODE_ON_ROWSTORE'
ORDER BY name;
GO








-----
-- Smaller dataset
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 
	YEAR(TransactionDate) AS YearSold,
	COUNT(VIN) AS NumVehiclesSold,
	AVG(SellPrice) AS AvgSellPrice
FROM dbo.SalesSummary
WHERE TransactionDate BETWEEN '2019-01-01' AND '2019-12-31 23:59.997'
GROUP BY YEAR(TransactionDate)
ORDER BY YEAR(TransactionDate);
GO

-- Larger dataset
SELECT 
	YEAR(TransactionDate) AS YearSold,
	COUNT(VIN) AS NumVehiclesSold,
	AVG(SellPrice) AS AvgSellPrice1
FROM dbo.SalesSummary
GROUP BY YEAR(TransactionDate)
ORDER BY YEAR(TransactionDate);
GO

-- Logical Reads:
-- SQL Server Execution Times:








-----
-- Ctrl-M: Turn on Actual Execution Plan
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ON_ROWSTORE = ON;
GO








-----
-- Smaller dataset
SELECT 
	YEAR(TransactionDate) AS YearSold,
	COUNT(VIN) AS NumVehiclesSold,
	AVG(SellPrice) AS AvgSellPrice
FROM dbo.SalesSummary
WHERE TransactionDate BETWEEN '2019-01-01' AND '2019-12-31 23:59.997'
GROUP BY YEAR(TransactionDate)
ORDER BY YEAR(TransactionDate);
GO

-- Larger dataset
SELECT 
	YEAR(TransactionDate) AS YearSold,
	COUNT(VIN) AS NumVehiclesSold,
	AVG(SellPrice) AS AvgSellPrice1
FROM dbo.SalesSummary
GROUP BY YEAR(TransactionDate)
ORDER BY YEAR(TransactionDate);
GO

-- Logical Reads:
-- SQL Server Execution Times:





-----
-- Key Takeaway:
-- Batch mode on rowstore helps only by reducing CPU consumption. 
--
-- If your bottleneck is I/O-related, and data isn't already cached ("cold" cache), 
-- batch mode on rowstore will not improve query elapsed time. Similarly, if there is 
-- no sufficient memory on the machine to cache all data, a performance improvement is unlikely.
--
-- Source
-- https://docs.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing?view=sql-server-ver15#batch-mode-on-rowstore








-----
-- 131072 is apparently the magic number
-- Source: http://www.queryprocessor.com/batch-mode-on-row-store/
USE tempdb;
GO

-- Re-Check Database Scoped Configurations
SELECT name, value, is_value_default
FROM sys.database_scoped_configurations
WHERE name = 'BATCH_MODE_ON_ROWSTORE'
ORDER BY name;
GO

-----
-- SETUP
DROP TABLE IF EXISTS t_131071_a;
DROP TABLE IF EXISTS t_131072_a;
GO

CREATE TABLE t_131071_a (
	RecID BIGINT IDENTITY(1, 1) PRIMARY KEY CLUSTERED,
	myValue VARCHAR(256)
);

CREATE TABLE t_131072_a (
	RecID BIGINT IDENTITY(1, 1) PRIMARY KEY CLUSTERED,
	myValue VARCHAR(256)
);


INSERT INTO t_131071_a (myValue)
SELECT TOP 131071 t1.name
FROM sys.objects t1
CROSS APPLY sys.columns t2
CROSS APPLY sys.indexes t3;


INSERT INTO t_131072_a (myValue)
SELECT TOP 131072 t1.name
FROM sys.objects t1
CROSS APPLY sys.columns t2
CROSS APPLY sys.indexes t3;

-- END SETUP
-----








-----------
-- Run sample query against both tables
-- Ctrl-M: Turn on Actual Execution Plan
SELECT SUM(RecID) OVER()
FROM t_131071_a;

SELECT SUM(RecID) OVER()
FROM t_131072_a;
