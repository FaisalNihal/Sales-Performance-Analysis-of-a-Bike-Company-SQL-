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
# Step 2: Create a procedure to track the important matrics (use parameter to track matrics by year/month/overall)
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

# Step 3: Sales trend over time
I analyzed sales performance over time by calculating monthly revenue, cumulative revenue, and a 3-month moving average, which can assist in identifying trends and supporting future sales forecasting.
**Sales trend over times (bikes)**
```sql
WITH t1 AS (
    SELECT 
        EXTRACT(YEAR FROM sales.`OrderDate`) AS _year,
        EXTRACT(MONTH FROM sales.`OrderDate`) AS _month,
        COUNT(sales.`ProductKey`) AS order_number,
        SUM(sales.`OrderQuantity`) AS order_quantity,
        ROUND(
            SUM(sales.`OrderQuantity` * prod.`ProductPrice`), 
            0
        ) AS revenue,
        ROUND(
            (
                SUM(sales.`OrderQuantity` * prod.`ProductPrice`) - 
                SUM(sales.`OrderQuantity` * prod.`ProductCost`)
            ) * 100 / 
            SUM(sales.`OrderQuantity` * prod.`ProductCost`), 
            0
        ) AS profit_per,
        COUNT(DISTINCT sales.`CustomerKey`) AS customer_number,
        COUNT(DISTINCT sales.`ProductKey`) AS number_of_product
    FROM 
        `adventureworks sales data` AS sales
    JOIN 
        `product lookup` AS prod 
        ON prod.`ProductKey` = sales.`ProductKey`
    WHERE 
        prod.`ProductSubcategoryKey`  BETWEEN 1 AND 3
    GROUP BY 
        EXTRACT(YEAR FROM sales.`OrderDate`), 
        EXTRACT(MONTH FROM sales.`OrderDate`)
    ORDER BY 
        EXTRACT(YEAR FROM sales.`OrderDate`), 
        EXTRACT(MONTH FROM sales.`OrderDate`)
)

SELECT 
    _year,
    _month,
    order_quantity
FROM 
    t1;
```
**Output**
<img width="752" height="452" alt="image" src="https://github.com/user-attachments/assets/97f95bf8-d8ed-4de4-9d94-a0a9e5bc6454" />

**Sales trend over time (Other Accessories)**
```sql
WITH t1 AS (
    SELECT 
        EXTRACT(YEAR FROM sales.`OrderDate`) AS _year,
        EXTRACT(MONTH FROM sales.`OrderDate`) AS _month,
        COUNT(sales.`ProductKey`) AS order_number,
        SUM(sales.`OrderQuantity`) AS order_quantity,
        ROUND(
            SUM(sales.`OrderQuantity` * prod.`ProductPrice`), 
            0
        ) AS revenue,
        ROUND(
            (
                SUM(sales.`OrderQuantity` * prod.`ProductPrice`) - 
                SUM(sales.`OrderQuantity` * prod.`ProductCost`)
            ) * 100 / 
            SUM(sales.`OrderQuantity` * prod.`ProductCost`), 
            0
        ) AS profit_per,
        COUNT(DISTINCT sales.`CustomerKey`) AS customer_number,
        COUNT(DISTINCT sales.`ProductKey`) AS number_of_product
    FROM 
        `adventureworks sales data` AS sales
    JOIN 
        `product lookup` AS prod 
        ON prod.`ProductKey` = sales.`ProductKey`
    WHERE 
        prod.`ProductSubcategoryKey` NOT BETWEEN 1 AND 3
    GROUP BY 
        EXTRACT(YEAR FROM sales.`OrderDate`), 
        EXTRACT(MONTH FROM sales.`OrderDate`)
    ORDER BY 
        EXTRACT(YEAR FROM sales.`OrderDate`), 
        EXTRACT(MONTH FROM sales.`OrderDate`)
)

SELECT 
    _year,
    _month,
    order_quantity
FROM 
    t1;
```
**Output**
<img width="752" height="452" alt="image" src="https://github.com/user-attachments/assets/e5191e84-4f40-45d2-b570-74e40c2c461e" />

**Cumulative revenue over time**
```sql
SELECT 
    EXTRACT(YEAR FROM sales.`OrderDate`) AS _year,
    EXTRACT(MONTH FROM sales.`OrderDate`) AS _month,
    revenue,
    SUM(revenue) OVER (
        ORDER BY 
            EXTRACT(YEAR FROM sales.`OrderDate`), 
            EXTRACT(MONTH FROM sales.`OrderDate`)
    ) AS cumulative_revenue
FROM 
    `sales_trend_over_time` AS sales
ORDER BY 
    EXTRACT(YEAR FROM sales.`OrderDate`), 
    EXTRACT(MONTH FROM sales.`OrderDate`) ASC;
```
**Output**
<img width="752" height="452" alt="image" src="https://github.com/user-attachments/assets/50b5bd2f-9509-44de-a4fa-a5e80fee9a95" />

**3 Month Moving Average (used to forecast future sales revenue)**
```sql
SELECT 
    EXTRACT(YEAR FROM sales.`OrderDate`) AS _year,
    EXTRACT(MONTH FROM sales.`OrderDate`) AS _month,
    revenue,
    ROUND(
        AVG(revenue) OVER (
            ORDER BY 
                EXTRACT(YEAR FROM sales.`OrderDate`), 
                EXTRACT(MONTH FROM sales.`OrderDate`)
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        0
    ) AS moving_avg_3_month
FROM 
    `sales_trend_over_time` AS sales
ORDER BY 
    EXTRACT(YEAR FROM sales.`OrderDate`), 
    EXTRACT(MONTH FROM sales.`OrderDate`) ASC;
```
**Output**
| year | month_ | revenue | 3 month moving_average |
| ---- | ------ | ------- | ---------------------- |
| 2020 | 1      | 585313  | 585313                 |
| 2020 | 2      | 532226  | 558770                 |
| 2020 | 3      | 643436  | 586992                 |
| 2020 | 4      | 653364  | 609675                 |
| 2020 | 5      | 659326  | 652042                 |
| 2020 | 6      | 669989  | 660893                 |
| 2020 | 7      | 486115  | 605143                 |
| 2020 | 8      | 536453  | 564186                 |
| 2020 | 9      | 344063  | 455544                 |
| 2020 | 10     | 404277  | 428264                 |
| 2020 | 11     | 326611  | 358317                 |
| 2020 | 12     | 563762  | 431550                 |
| 2021 | 1      | 432426  | 440933                 |
| 2021 | 2      | 474163  | 490117                 |
| 2021 | 3      | 471962  | 459517                 |
| 2021 | 4      | 494957  | 480361                 |
| 2021 | 5      | 545535  | 504151                 |
| 2021 | 6      | 533825  | 524772                 |
| 2021 | 7      | 815356  | 631572                 |
| 2021 | 8      | 804193  | 717791                 |

# Step 4: Customer Wise Performance Analysis
**Total Customer**
```sql
select count(`CustomerKey`) as Total_customer from ` customer lookup`;
```
**Output**
| Total_customer |
| -------------- |
| 18148          |

**Number of new customer in each year**
```sql
WITH t1 AS (
    SELECT 
        EXTRACT(YEAR FROM `OrderDate`) AS year_,
        `CustomerKey`,
        COUNT(`OrderDate`) AS order_count,
        ROW_NUMBER() OVER (
            PARTITION BY `CustomerKey` 
            ORDER BY EXTRACT(YEAR FROM `OrderDate`)
        ) AS row_
    FROM 
        `adventureworks sales data`
    GROUP BY 
        EXTRACT(YEAR FROM `OrderDate`), 
        `CustomerKey`
)

SELECT 
    year_,
    COUNT(`CustomerKey`) AS new_customers
FROM 
    t1
WHERE 
    row_ = 1
GROUP BY 
    year_;
```
**Output**
| year | New Customer_number |
| ---- | ------------------- |
| 2021 | 7929                |
| 2022 | 6857                |
| 2020 | 2630                |





