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

**Number of customer and revenue per customer by income_category**
``` sql
select income_category,count(customerkey) as num_customer, sum(revenue)/count(customerkey) as rev_per_cust
from `final_customer`
where ordernumber<>0
group by income_category;
```
**Output**
| income_category | number ofcustomer | revenue_per_customer |
| --------------- | ----------------- | -------------------- |
| mid             | 4879              | 1674.080344          |
| low             | 6075              | 1209.323951          |
| very low        | 4922              | 1029.425843          |
| very high       | 197               | 2141.649746          |
| high            | 1343              | 1964.960536          |

<img width="793" height="452" alt="image" src="https://github.com/user-attachments/assets/54f53d59-fa83-4fd0-ae4a-933c2d4b2d73" />



**Number of customer who have no sales record (might be purchased product before the given time period)**
```sql
select count(customerkey)*100/(select count(customerkey) from `final_customer`) from `final_customer`
where ordernumber=0;
```
**Output**
| No sales customer % |
| ------------------- |
| 4.0335              |

**Customers who buy our main product(Bike) but didn't purchase any accessories**
```sql
WITH t1 AS (
    SELECT 
        cust.`CustomerKey`, 
        SUM(sales.`OrderQuantity`) AS sum_,
        MAX(sales.`OrderDate`) AS _max
    FROM 
        `customer lookup` AS cust
    LEFT JOIN 
        `adventureworks sales data` AS sales 
        ON cust.`CustomerKey` = sales.`CustomerKey`
    JOIN 
        `product lookup` AS prod 
        ON sales.`ProductKey` = prod.`ProductKey`
    WHERE 
        prod.`ProductSubcategoryKey` IN (1, 2, 3)
    GROUP BY 
        cust.`CustomerKey`
),

t2 AS (
    SELECT 
        cust.`CustomerKey`, 
        SUM(sales.`OrderQuantity`) AS Acce_sum_,
        MAX(sales.`OrderDate`) AS _max
    FROM 
        `customer lookup` AS cust
    LEFT JOIN 
        `adventureworks sales data` AS sales 
        ON cust.`CustomerKey` = sales.`CustomerKey`
    JOIN 
        `product lookup` AS prod 
        ON sales.`ProductKey` = prod.`ProductKey`
    WHERE 
        prod.`ProductSubcategoryKey` NOT IN (1, 2, 3)
    GROUP BY 
        cust.`CustomerKey`
),

t3 AS (
    SELECT 
        t1.*, 
        t2.Acce_sum_
    FROM 
        t1
    LEFT JOIN 
        t2 ON t1.`CustomerKey` = t2.`CustomerKey`
)

SELECT 
    `CustomerKey`
FROM 
    t3
WHERE 
    Acce_sum_ IS NULL;
```
**Output**
**Customer number: 1258**
| CustomerKey |
| ----------- |
| 12483       |
| 11759       |
| 12464       |
| 14722       |
| 11129       |
| 12547       |

**Top 3 Customers of Each Country**
```sql
WITH t1 AS (
    SELECT 
        sales.`CustomerKey`, 
        (sales.`OrderQuantity` * prod.`ProductPrice`) AS revenue,
        sales.`TerritoryKey`
    FROM 
        `adventureworks sales data` AS sales
    JOIN 
        `product lookup` AS prod 
        ON prod.`ProductKey` = sales.`ProductKey`
),

t2 AS (
    SELECT 
        t1.`CustomerKey`, 
        terr.`Country`, 
        ROUND(SUM(t1.`revenue`), 0) AS total_revenue
    FROM 
        t1
    JOIN 
        `territory lookup` AS terr 
        ON t1.`TerritoryKey` = terr.`SalesTerritoryKey`
    GROUP BY 
        t1.`CustomerKey`, 
        terr.`Country`
),

t3 AS (
    SELECT 
        `CustomerKey`, 
        `Country`, 
        `total_revenue`,
        RANK() OVER (
            PARTITION BY `Country` 
            ORDER BY `total_revenue` DESC
        ) AS _rank_
    FROM 
        t2
)

SELECT 
    `CustomerKey`, 
    `Country`, 
    `total_revenue`, 
    _rank_
FROM 
    t3
WHERE 
    _rank_ <= 3;
```
**Output**
| customerkey | country        | total_revenue | _rank_ |
| ----------- | -------------- | ------------- | ------ |
| 11767       | Australia      | 8118          | 1      |
| 11766       | Australia      | 8098          | 2      |
| 11456       | Australia      | 8064          | 3      |
| 23074       | Canada         | 6044          | 1      |
| 23057       | Canada         | 6020          | 2      |
| 22881       | Canada         | 5997          | 3      |
| 11433       | France         | 12408         | 1      |
| 11439       | France         | 12015         | 2      |
| 11241       | France         | 11330         | 3      |
| 11245       | Germany        | 10166         | 1      |
| 11237       | Germany        | 10065         | 2      |
| 11428       | Germany        | 9762          | 3      |
| 15106       | United Kingdom | 8186          | 1      |
| 15097       | United Kingdom | 8150          | 2      |
| 15692       | United Kingdom | 8146          | 3      |
| 11175       | United States  | 6537          | 1      |
| 11171       | United States  | 6535          | 2      |
| 11259       | United States  | 6523          | 3      |

**Number of retail customers of Accessories**
```sql
with t1 as (select `customerkey`,`acce_sum`,`max`,datediff((select max(orderdate) from`adventureworks sales data`),`max`) _last from `sales_amount_by_customer`
where `acce_sum`>20 and _sum is null)
select count(`customerkey`) as retail_customer_number from t1
```
**Output**
| retail_customer_number |
| ---------------------- |
| 68                     |

**List of retail customers who has high chance to become churned(didn't place any order in last 2 month)**
```sql
with t1 as(select `customerkey`,`acce_sum`,`max`,datediff((select max(orderdate) from`adventureworks sales data`),`max`) _last from `sales_amount_by_customer`
where `acce_sum`>20 and _sum is null)
select `customerkey`,`acce_sum` from t1 
where _last>60;
```
**Output**
**Churned Customer number: 21**
| customerkey | accessories Order quantity |
| ----------- | -------------------------- |
| 11530       | 43                         |
| 17374       | 21                         |
| 12165       | 28                         |
| 12202       | 23                         |
| 13318       | 21                         |

**List of customers who buy at least one bike and 10 accessories**
```sql
select `customerkey`,`acce_sum`,`max`,datediff((select max(orderdate) from`adventureworks sales data`),`max`) _last from `sales_amount_by_customer`
where `acce_sum`>=10 and _sum>=1;
```
**Output**
**Customer Number: 185**
| customerkey | max_order_date |
| ----------- | -------------- |
| 11400       | 20/01/2022     |
| 11457       | 03/12/2021     |
| 11456       | 02/12/2021     |
| 11451       | 07/12/2021     |
| 11761       | 30/01/2022     |
| 14171       | 14/06/2022     |
| 15059       | 22/06/2022     |

**List of customers who buy more than 2 bikes and their last purchase is within 100 days and overall purchase duration is more then 300 days**
```sql
WITH t1 AS (
    SELECT 
        s.`CustomerKey`, 
        SUM(s.`OrderQuantity`) AS orderquantity,
        SUM(s.`OrderQuantity` * p.`ProductPrice`) / SUM(s.`OrderQuantity`) AS revenue_per_order,
        MIN(s.`OrderDate`) AS min_,
        DATEDIFF(
            (SELECT MAX(`OrderDate`) FROM `adventureworks sales data`),
            MAX(s.`OrderDate`)
        ) AS _last,
        DATEDIFF(MAX(s.`OrderDate`), MIN(s.`OrderDate`)) AS _duration
    FROM 
        `product lookup` AS p
    JOIN 
        `adventureworks sales data` AS s 
        ON p.`ProductKey` = s.`ProductKey`
    WHERE 
        p.`ProductSubcategoryKey` BETWEEN 1 AND 3
    GROUP BY 
        s.`CustomerKey`
    HAVING 
        SUM(s.`OrderQuantity`) > 2
)

SELECT 
    `CustomerKey`, 
    orderquantity, 
    min_, 
    _last, 
    _duration
FROM 
    t1
WHERE 
    _last < 100 
    AND _duration > 300;
```
**Output**
**Customer Number:426**
| customerkey | orderquantity | 1st order  | Last purchase(day) | Customer_lifetime |
| ----------- | ------------- | ---------- | ------------------ | ----------------- |
| 14947       | 3             | 02/01/2020 | 51                 | 859               |
| 14937       | 3             | 07/01/2020 | 49                 | 856               |
| 14950       | 3             | 13/01/2020 | 11                 | 888               |
| 14941       | 3             | 14/01/2020 | 32                 | 866               |
| 11750       | 3             | 14/01/2020 | 88                 | 810               |

**Number of new customers of each income category in 2022**
```sql
select f.`income_category`,count(distinct s.`CustomerKey`) from `final_customer` f join `adventureworks sales data`s
on f.customerkey=s.customerkey 
where year(s.orderdate)=2022 and s.`CustomerKey` not in (select distinct customerkey from`adventureworks sales data`
where year(orderdate)<2022)
group by f.`income_category`;
```
**Output**
| income_category | New Customer (2022) |
| --------------- | ------------------- |
| high            | 445                 |
| low             | 2466                |
| mid             | 1862                |
| very high       | 70                  |
| very low        | 2014                |


