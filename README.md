# Sales-Performance-Analysis-of-a-Bike-Company-SQL-
his SQL-based analytics project explores sales performance of a bike company using a snowflake schema data model. The project focuses on evaluating revenue, profit, and order trends, understanding customer behavior, and assessing the impact of product line expansion between 2020 and mid-2022.

# Company Overview
The dataset represents a bike company operating from January 2020 to June 2022. During its initial phase in 2020, the company sold only Mountain Bikes and Road Bikes. In July 2021, it diversified its product line by introducing:

**1**. Touring Bikes

**2**. Bike Accessories

**3**. Bike Clothing

**4**. Bike Components


**The data is structured in a snowflake schema, including the following key tables**

**1**. fact_sales – sales transactions (quantity, revenue, profit)

**2**. product, product_subcategory, product_category – product hierarchy

**3**. customer – customer profiles

**4**. territory – geographic sales zones

**5**. product_return – returned products and quantities

# Project Objectives
**1**. Analyze Overall Business Trends
Track changes in revenue, profit, order quantity, and order volume over the full time period (2020–2022).

**2**. Assess New Product Performance
Evaluate sales and return behavior of newly launched products (Touring Bikes, Accessories, Clothing, Components) introduced in July 2021.

**3**. Understand Customer Purchase Behavior
Identify trends in repeat purchases, regional buying patterns, and product preferences across customer segments.

**4**. Identify Bottlenecks and Issues
Highlight high-return products, declining categories, and underperforming regions.

**5**. Deliver Actionable Insights
Provide recommendations based on data to enhance sales strategy, reduce returns, and optimize product offerings.

# Step 1: Data Tables Inspection
In the first step, I inspected the data tables to identify null values, duplicate primary keys in dimension tables, duplicate records in the fact table, and any unwanted or inconsistent values.

```sql
-- ========================
-- Customer Table Inspection
-- ========================

-- 1. Check for duplicate values in primary column (CustomerKey)
SELECT CustomerKey, COUNT(CustomerKey) AS count
FROM `customer lookup`
GROUP BY CustomerKey
ORDER BY count DESC;

-- 2. Remove unwanted columns
ALTER TABLE `customer lookup`
DROP COLUMN `MaritalStatus`,
DROP COLUMN `TotalChildren`,
DROP COLUMN `EducationLevel`,
DROP COLUMN `HomeOwner`;

-- 3. Check for null values in important columns
SELECT `BirthDate`, `Gender`, `AnnualIncome`, `Occupation`
FROM `customer lookup`
WHERE `BirthDate` IS NULL 
   OR `Gender` IS NULL 
   OR `AnnualIncome` IS NULL 
   OR `Occupation` IS NULL;

-- ========================
-- Fact Table Inspection
-- ========================

-- 4. Check for duplicate records
SELECT COUNT(*) AS total_records FROM `adventureworks sales data`;

SELECT COUNT(*) AS distinct_records
FROM (SELECT DISTINCT * FROM `adventureworks sales data`) AS t1;

-- 5. Check for null values in key columns
SELECT `ProductKey`, `CustomerKey`, `TerritoryKey`, `OrderLineItem`, `OrderQuantity`
FROM `adventureworks sales data`
WHERE `ProductKey` IS NULL 
   OR `CustomerKey` IS NULL 
   OR `TerritoryKey` IS NULL 
   OR `OrderLineItem` IS NULL 
   OR `OrderQuantity` IS NULL;

-- 6. Delete records with null OrderQuantity
DELETE FROM `adventureworks sales data` 
WHERE `OrderQuantity` IS NULL;

-- ========================
-- Product Table Inspection
-- ========================

-- 7. Check for duplicate values in primary column (ProductKey)
SELECT ProductKey, COUNT(ProductKey) AS count
FROM `product lookup`
GROUP BY ProductKey
ORDER BY count DESC;
```
# Create a procedure to track the important matrics (use parameter to track matrics by year/month/overall)
In the second step, I created a stored procedure to dynamically track key performance metrics—revenue, profit, number of orders, customers, and total order quantity—based on a given filter (year, month, or overall), enabling flexible and parameter-driven analysis.
```sql
DELIMITER $$

CREATE PROCEDURE Overall_performance_by_month_year (
    IN in_year INT,
    IN in_month INT
)
BEGIN
    IF in_year IS NULL AND in_month IS NULL THEN
        -- No filter: return overall performance metrics
        SELECT 
            COUNT(sales.`ProductKey`) AS order_number,
            SUM(sales.`OrderQuantity`) AS order_quantity,
            SUM(sales.`OrderQuantity` * prod.`ProductPrice`) AS revenue,
            (
                SUM(sales.`OrderQuantity` * prod.`ProductPrice`) - 
                SUM(sales.`OrderQuantity` * prod.`ProductCost`)
            ) * 100 / SUM(sales.`OrderQuantity` * prod.`ProductCost`) AS profit_per,
            COUNT(DISTINCT sales.`CustomerKey`) AS customer_number
        FROM 
            `adventureworks sales data` AS sales
        JOIN 
            `product lookup` AS prod
        ON 
            sales.`ProductKey` = prod.`ProductKey`;

    ELSE
        -- Filtered by year and/or month: return performance metrics for the given period
        SELECT 
            COUNT(sales.`ProductKey`) AS order_number,
            SUM(sales.`OrderQuantity`) AS order_quantity,
            SUM(sales.`OrderQuantity` * prod.`ProductPrice`) AS revenue,
            (
                SUM(sales.`OrderQuantity` * prod.`ProductPrice`) - 
                SUM(sales.`OrderQuantity` * prod.`ProductCost`)
            ) * 100 / SUM(sales.`OrderQuantity` * prod.`ProductCost`) AS profit_per,
            COUNT(DISTINCT sales.`CustomerKey`) AS customer_number
        FROM 
            `adventureworks sales data` AS sales
        JOIN 
            `product lookup` AS prod
        ON 
            sales.`ProductKey` = prod.`ProductKey`
        WHERE 
            (in_year IS NULL OR YEAR(sales.`OrderDate`) = in_year)
            AND (in_month IS NULL OR MONTH(sales.`OrderDate`) = in_month);
    END IF;
END $$

DELIMITER ;

-- ✅ Example: Call procedure for overall performance
CALL Overall_performance_by_month_year(2022, 5);
```
**OUTPUT**
| order_number | order_quantity | revenue     | profit      | Customer_number |
| ------------ | -------------- | ----------- | ----------- | --------------- |
| 5416         | 8199           | 1768432.507 | 73.77129195 | 2105            |



