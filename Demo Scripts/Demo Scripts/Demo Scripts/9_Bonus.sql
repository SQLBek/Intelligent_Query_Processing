/*-------------------------------------------------------------------
-- 9 - Bonus
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
-- Setup
DROP TABLE IF EXISTS demo.Strings;
GO
CREATE TABLE demo.Strings (
	MyString VARCHAR(10)
);
GO








-----
-- Boring INSERT
INSERT INTO demo.Strings 
SELECT 'foo' UNION ALL
SELECT 'bar';


SELECT MyString 
FROM demo.Strings;
GO








-----
-- INSERT with longer string
INSERT INTO demo.Strings 
SELECT '0123456789' UNION ALL
SELECT '01234567890123456789';


SELECT MyString
FROM demo.Strings;
GO








-----
-- Expand MyString size
DROP TABLE IF EXISTS demo.Strings;
GO
CREATE TABLE demo.Strings (
	MyString VARCHAR(125)
);
GO


-----
-- INSERT with longer string
INSERT INTO demo.Strings 
SELECT '0123456789' UNION ALL
SELECT '01234567890123456789';


SELECT MyString
FROM demo.Strings;
GO








-----
-- INSERT MUCH LONGER character string
INSERT INTO demo.Strings 
SELECT '012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890123456789';
GO






