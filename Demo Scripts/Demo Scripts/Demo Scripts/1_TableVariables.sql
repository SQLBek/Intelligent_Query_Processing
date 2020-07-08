/*-------------------------------------------------------------------
-- 1 - Table Variables
-- 
-- Summary: 
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/
USE AutoDealershipDemo
GO
SET STATISTICS IO ON
SET STATISTICS TIME ON
GO


-----
-- Must disable Adaptive Joins & Batch Mode first
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ADAPTIVE_JOINS = OFF;
GO
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ON_ROWSTORE = OFF;
GO








-----
-- Database Scoped Configurations
-- https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-scoped-configurations-transact-sql?view=sql-server-ver15
SELECT name, value, is_value_default
FROM sys.database_scoped_configurations
WHERE name = 'DEFERRED_COMPILATION_TV'
ORDER BY name;
GO








-----
-- Turn OFF DEFERRED_COMPILATION_TV
ALTER DATABASE SCOPED CONFIGURATION
SET DEFERRED_COMPILATION_TV = OFF;
GO








-----
-- Manual setup for this specific example
DROP TABLE IF EXISTS #tmpCustomer;
DROP TABLE IF EXISTS #tmpSalesHistory;
GO

-- Insert 1 CustomerID into #tmpCustomer
SELECT TOP 1 CustomerID
INTO #tmpCustomer
FROM dbo.SalesHistory
GROUP BY CustomerID
HAVING COUNT(1) > 500;

-- Insert 500,000 records into #tmpSalesHistory
SELECT TOP 500000 *
INTO #tmpSalesHistory
FROM dbo.SalesHistory;

-- Ensure the one customer we pulled prior is in the temp table!
INSERT INTO #tmpSalesHistory (
	CustomerID, SalesPersonID, InventoryID,
	TransactionDate, SellPrice
)
SELECT 
	SalesHistory.CustomerID,
	SalesHistory.SalesPersonID,
	SalesHistory.InventoryID,
	SalesHistory.TransactionDate,
	SalesHistory.SellPrice
FROM dbo.SalesHistory
WHERE EXISTS (
	SELECT 1
	FROM #tmpCustomer
	WHERE #tmpCustomer.CustomerID = SalesHistory.CustomerID
);

-- Create clustered & nonclustered indexes
CREATE CLUSTERED INDEX IX_CustomerID ON #tmpCustomer (CustomerID);
CREATE CLUSTERED INDEX IX_SalesHistoryID ON #tmpSalesHistory (SalesHistoryID);

CREATE NONCLUSTERED INDEX IX_SalesHistoryID_CustomerID ON #tmpSalesHistory (CustomerID);
GO

-- End Setup
-----








-----
-- Baseline - two table join
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID
FROM #tmpSalesHistory AS SalesHistory
INNER JOIN #tmpCustomer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);
GO

-- Logical Reads:
-- SQL Server Execution Times:
-- Query Cost: 




-----
-- Review execution plan
-- Estimated # of rows?
-- When you have 1 table with 1 rec & another with many, you'll get a nested loop join








-----
-- Table Variable with one record
DECLARE @Customer TABLE (
	CustomerID INT INDEX CX_CustomerID CLUSTERED
);

-- Insert 1 record into Table Variable
INSERT INTO @Customer
SELECT
	CustomerID
FROM #tmpCustomer;

-- Compare
PRINT '-- Table Variable --';
SELECT 'Table Variable', 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID
FROM #tmpSalesHistory AS SalesHistory
INNER JOIN @Customer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);

PRINT '-- Temp Table--';
SELECT 'Temp Table', 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID
FROM #tmpSalesHistory AS SalesHistory
INNER JOIN #tmpCustomer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);
GO

-- Logical Reads:
-- SQL Server Execution Times:
-- Query Cost: 








-----
-- Table Variable with many records

-- Reset #tmpCustomer; had 1 record before, now insert 500,000 records
TRUNCATE TABLE #tmpCustomer;

INSERT INTO #tmpCustomer (
	CustomerID
)
SELECT TOP 500000 CustomerID
FROM dbo.SalesHistory
ORDER BY CustomerID;	-- ORDER BY to ensure same set of CustomerIDs get put into dbo.SalesHistory between runs
GO




-----
-- Re-run comparison test
-- Using INSERT INTO temp tables to eliminate long waiting due to ASYNC NETWORK IO waits
DROP TABLE IF EXISTS #outputOne;
DROP TABLE IF EXISTS #outputTwo;
GO

DECLARE @Customer TABLE (
	CustomerID INT INDEX CX_CustomerID CLUSTERED
);

INSERT INTO @Customer
SELECT
	CustomerID
FROM #tmpCustomer;

-- Compare
PRINT '-- Table Variable --';
SELECT 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID AS CustID2
INTO #outputOne
FROM #tmpSalesHistory AS SalesHistory
INNER JOIN @Customer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);

PRINT '-- Temp Table--';
SELECT 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID AS CustID2
INTO #outputTwo
FROM #tmpSalesHistory AS SalesHistory
INNER JOIN #tmpCustomer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);
GO

-- Logical Reads:
-- SQL Server Execution Times:
-- Query Cost: 







-----
-- Turn ON DEFERRED_COMPILATION_TV
ALTER DATABASE SCOPED CONFIGURATION
SET DEFERRED_COMPILATION_TV = ON;
GO




-----
-- Re-run comparison test
DROP TABLE IF EXISTS #outputOne;
DROP TABLE IF EXISTS #outputTwo;
GO

DECLARE @Customer TABLE (
	CustomerID INT INDEX CX_CustomerID CLUSTERED
);

INSERT INTO @Customer
SELECT
	CustomerID
FROM #tmpCustomer;

-- Compare
PRINT '-- Table Variable --';
SELECT 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID AS CustID2
INTO #outputOne
FROM #tmpSalesHistory AS SalesHistory
INNER JOIN @Customer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);

PRINT '-- Temp Table--';
SELECT 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID AS CustID2
INTO #outputTwo
FROM #tmpSalesHistory AS SalesHistory
INNER JOIN #tmpCustomer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);
GO

-- Logical Reads:
-- SQL Server Execution Times:
-- Query Cost: 





-----
-- Why one of the key differences?
-- https://docs.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing?view=sql-server-ver15#table-variable-deferred-compilation
-- "... this feature doesn't add column statistics to table variables."





-----
-- If we get a MERGE JOIN
-- Re-run with a HASH JOIN HINT
DROP TABLE IF EXISTS #outputOne;
DROP TABLE IF EXISTS #outputTwo;
GO

DECLARE @Customer TABLE (
	CustomerID INT INDEX CX_CustomerID CLUSTERED
);

INSERT INTO @Customer
SELECT
	CustomerID
FROM #tmpCustomer;

-- Compare
PRINT '-- Table Variable --';
SELECT 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID AS CustID2
INTO #outputOne
FROM #tmpSalesHistory AS SalesHistory
INNER HASH JOIN @Customer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);

PRINT '-- Temp Table--';
SELECT 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID AS CustID2
INTO #outputTwo
FROM #tmpSalesHistory AS SalesHistory
INNER JOIN #tmpCustomer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);
GO








-----
-- Batch mode!
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ON_ROWSTORE = ON;
GO








-----
-- Re-run with a HASH JOIN HINT
DROP TABLE IF EXISTS #outputOne;
DROP TABLE IF EXISTS #outputTwo;
GO

DECLARE @Customer TABLE (
	CustomerID INT INDEX CX_CustomerID CLUSTERED
);

INSERT INTO @Customer
SELECT
	CustomerID
FROM #tmpCustomer;

-- Compare
PRINT '-- Table Variable --';
SELECT 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID AS CustID2
INTO #outputOne
FROM #tmpSalesHistory AS SalesHistory
INNER HASH JOIN @Customer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);

PRINT '-- Temp Table--';
SELECT 
	SalesHistory.SalesHistoryID, SalesHistory.CustomerID, Customer.CustomerID AS CustID2
INTO #outputTwo
FROM #tmpSalesHistory AS SalesHistory
INNER JOIN #tmpCustomer AS Customer
	ON SalesHistory.CustomerID = Customer.CustomerID
OPTION(MAXDOP 1);
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
--------------
--------------
--------------
