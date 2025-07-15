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

# Step 5: Product Wise Performance Analysis
**Product category wise order number, order quantity, revenue and profit%**
```sql
SELECT 
    p.`CategoryName`,
    COUNT(c.OrderQuantity) AS order_number,
    SUM(c.OrderQuantity) AS order_quantity,
    ROUND(SUM(c.OrderQuantity * c.ProductPrice), 0) AS revenue,
    ROUND(
        (SUM(c.OrderQuantity * c.ProductPrice) - SUM(c.OrderQuantity * c.ProductCost)) * 100.0 
        / NULLIF(SUM(c.OrderQuantity * c.ProductCost), 0), 
        0
    ) AS profit_per
FROM 
    category c
RIGHT JOIN 
    `product categories lookup` p ON c.ProductCategoryKey = p.ProductCategoryKey
GROUP BY  
    p.`CategoryName`;
```
**Output**
| CategoryName | order_number | order_quantity | revenue  | profit% |
| ------------ | ------------ | -------------- | -------- | ------- |
| Bikes        | 13929        | 13929          | 23642495 | 70      |
| Components   | 0            | NULL           | NULL     | NULL    |
| Clothing     | 8510         | 12436          | 365419   | 79      |
| Accessories  | 33607        | 57809          | 906673   | 169     |

<img width="553" height="452" alt="image" src="https://github.com/user-attachments/assets/8a4b3929-1811-42ce-8cdf-1114d7005bdc" /> <br>


**Sales Analysis of main product(bikes)**
**Performance Summary of Different Bike Types**
```sql
SELECT 
    p.`SubcategoryName`,
    COUNT(DISTINCT c.ProductKey) AS number_of_product,
    SUM(c.OrderQuantity) AS order_quantity,
    ROUND(SUM(c.OrderQuantity * c.ProductPrice), 0) AS revenue,
    SUM(c.OrderQuantity) / COUNT(DISTINCT c.OrderDate) AS order_per_day,
    ROUND(
        (SUM(c.OrderQuantity * c.ProductPrice) - SUM(c.OrderQuantity * c.ProductCost)) * 100.0
        / NULLIF(SUM(c.OrderQuantity * c.ProductCost), 0),
        0
    ) AS profit
FROM 
    category c
JOIN 
    `product subcategories lookup` p ON c.ProductSubcategoryKey = p.ProductSubcategoryKey
WHERE 
    c.ProductCategoryKey = 1
GROUP BY  
    p.SubcategoryName;
```
**Output**
| SubcategoryName | number_of_product | order_quantity | revenue  | order_per_day | profit |
| --------------- | ----------------- | -------------- | -------- | ------------- | ------ |
| Mountain Bikes  | 28                | 4706           | 8583748  | 5.746         | 84     |
| Road Bikes      | 38                | 7099           | 11287183 | 7.8269        | 63     |
| Touring Bikes   | 22                | 2124           | 3771565  | 5.8352        | 61     |

<img width="654" height="452" alt="image" src="https://github.com/user-attachments/assets/8b046858-188c-4bd8-8e3e-ef4e67ae52bf" />


**Products which have no sales record(Bikes)**
```sql
select productkey,`ProductSubcategoryKey`,`ProductPrice` from `product lookup`
where `ProductSubcategoryKey` between 1 and 3 and productkey not in (select distinct productkey from `adventureworks sales data`);
```
**Output**
| productkey | ProductSubcategoryKey | ProductPrice |
| ---------- | --------------------- | ------------ |
| 315        | 2                     | 1457.99      |
| 316        | 2                     | 1457.99      |
| 317        | 2                     | 1457.99      |
| 318        | 2                     | 1457.99      |
| 319        | 2                     | 1457.99      |
| 364        | 1                     | 1079.99      |
| 365        | 1                     | 1079.99      |
| 366        | 1                     | 1079.99      |
| 367        | 1                     | 1079.99      |

**Revenue per order value in different years (bike)**
```sql
SELECT 
    YEAR(OrderDate) AS order_year,
    COUNT(ProductKey) AS total_order,
    ROUND(
        SUM(ProductPrice * OrderQuantity) / COUNT(ProductKey),
        0
    ) AS rev_per_order,
    ROUND(
        (SUM(ProductPrice * OrderQuantity) - SUM(ProductCost * OrderQuantity)) * 100.0
        / NULLIF(SUM(ProductCost * OrderQuantity), 0),
        0
    ) AS profit
FROM 
    `category`
WHERE 
    ProductCategoryKey = 1
GROUP BY 
    YEAR(OrderDate);
```

**Output**
| year | total_order | revenue_per_order | profit% |
| ---- | ----------- | ----------------- | ------- |
| 2020 | 2630        | 2435              | 68      |
| 2021 | 5610        | 1563              | 71      |
| 2022 | 5689        | 1489              | 70      |

<img width="630" height="361" alt="image" src="https://github.com/user-attachments/assets/cec5436d-4f93-49f8-92de-cbe45d751ab8" />


**YoY change of Order per Month  for low price bikes**
```sql
WITH t1 AS (
    SELECT  
        p.`SubcategoryName`, 
        YEAR(c.OrderDate) AS year_,
        SUM(c.OrderQuantity) AS order_quantity,
        SUM(c.OrderQuantity) / COUNT(DISTINCT MONTH(c.OrderDate)) AS order_per_month
    FROM 
        category c
    JOIN 
        `product subcategories lookup` p 
        ON c.ProductSubcategoryKey = p.ProductSubcategoryKey
    WHERE 
        c.ProductCategoryKey = 1 
        AND c.ProductPrice < 1500
    GROUP BY  
        p.SubcategoryName, 
        YEAR(c.OrderDate)
)

SELECT 
    *,
    LAG(order_per_month) OVER (
        PARTITION BY SubcategoryName 
        ORDER BY year_
    ) AS previous,
    
    order_per_month - LAG(order_per_month) OVER (
        PARTITION BY SubcategoryName 
        ORDER BY year_
    ) AS YOY
FROM 
    t1;
```
**Output**
| SubcategoryName | year | order_quantity | order_per_month | previous | YOY      |
| --------------- | ---- | -------------- | --------------- | -------- | -------- |
| Mountain Bikes  | 2021 | 395            | 65.8333         | NULL     | NULL     |
| Mountain Bikes  | 2022 | 611            | 101.8333        | 65.8333  | 36       |
| Road Bikes      | 2020 | 533            | 44.4167         | NULL     | NULL     |
| Road Bikes      | 2021 | 1542           | 128.5           | 44.4167  | 84.0833  |
| Road Bikes      | 2022 | 1427           | 237.8333        | 128.5    | 109.3333 |
| Touring Bikes   | 2021 | 373            | 62.1667         | NULL     | NULL     |
| Touring Bikes   | 2022 | 518            | 86.3333         | 62.1667  | 24.1666  |

<img width="642" height="412" alt="image" src="https://github.com/user-attachments/assets/345fac26-ec7c-425a-89d3-7171fd1ba7bf" />

**YoY change of Order per Month change for high price bikes**
```sql
WITH t1 AS (
    SELECT  
        p.`SubcategoryName`, 
        YEAR(c.OrderDate) AS year_,
        SUM(c.OrderQuantity) AS order_quantity,
        SUM(c.OrderQuantity) / COUNT(DISTINCT MONTH(c.OrderDate)) AS order_per_month
    FROM 
        category c
    JOIN 
        `product subcategories lookup` p 
        ON c.ProductSubcategoryKey = p.ProductSubcategoryKey
    WHERE 
        c.ProductCategoryKey = 1 
        AND c.ProductPrice > 2000
    GROUP BY  
        p.SubcategoryName, 
        YEAR(c.OrderDate)
)

SELECT 
    *,
    LAG(order_per_month) OVER (
        PARTITION BY SubcategoryName 
        ORDER BY year_
    ) AS previous,
    
    order_per_month - LAG(order_per_month) OVER (
        PARTITION BY SubcategoryName 
        ORDER BY year_
    ) AS YOY
FROM 
    t1;
```
**Output**
| SubcategoryName | year_ | order_quantity | order_per_month | previous | YOY       |
| --------------- | ----- | -------------- | --------------- | -------- | --------- |
| Mountain Bikes  | 2020  | 603            | 50.25           | NULL     | NULL      |
| Mountain Bikes  | 2021  | 1656           | 138             | 50.25    | 87.75     |
| Mountain Bikes  | 2022  | 1441           | 240.1667        | 138      | 102.1667  |
| Road Bikes      | 2020  | 1494           | 124.5           | NULL     | NULL      |
| Road Bikes      | 2021  | 895            | 74.5833         | 124.5    | \-49.9167 |
| Road Bikes      | 2022  | 297            | 49.5            | 74.5833  | \-25.0833 |
| Touring Bikes   | 2021  | 438            | 73              | NULL     | NULL      |
| Touring Bikes   | 2022  | 795            | 132.5           | 73       | 59.5      |

<img width="752" height="413" alt="image" src="https://github.com/user-attachments/assets/5165e61f-fc65-4679-9f82-9c02bdce92c7" />

**Top 3 selling products(bike) of every country**
```sql
WITH t1 AS (
    SELECT 
        s.ProductKey,
        p.ProductSubcategoryKey,
        (s.OrderQuantity * p.ProductPrice) AS revenue,
        s.TerritoryKey
    FROM 
        `product lookup` p
    JOIN 
        `adventureworks sales data` s ON p.ProductKey = s.ProductKey
    WHERE 
        p.ProductSubcategoryKey BETWEEN 1 AND 3
),

t2 AS (
    SELECT 
        t1.ProductKey, 
        t.Country,
        ROUND(SUM(t1.revenue), 0) AS total_revenue
    FROM 
        t1
    JOIN 
        `territory lookup` t ON t1.TerritoryKey = t.SalesTerritoryKey
    GROUP BY 
        t1.ProductKey, 
        t.Country
),

t3 AS (
    SELECT 
        ProductKey, 
        Country, 
        total_revenue,
        RANK() OVER (PARTITION BY Country ORDER BY total_revenue DESC) AS _rank_
    FROM 
        t2
)

SELECT 
    ProductKey, 
    Country, 
    total_revenue, 
    _rank_
FROM 
    t3
WHERE 
    _rank_ <= 3;
```
**Output**
| productkey | country        | total_revenue | _rank_ |
| ---------- | -------------- | ------------- | ------ |
| 360        | Australia      | 342199        | 1      |
| 352        | Australia      | 339713        | 2      |
| 354        | Australia      | 323141        | 3      |
| 360        | Canada         | 120897        | 1      |
| 312        | Canada         | 89457         | 2      |
| 313        | Canada         | 85878         | 3      |
| 362        | France         | 127044        | 1      |
| 360        | France         | 120897        | 2      |
| 356        | France         | 118071        | 3      |
| 356        | Germany        | 149142        | 1      |
| 362        | Germany        | 147535        | 2      |
| 352        | Germany        | 136714        | 3      |
| 360        | United Kingdom | 157781        | 1      |
| 358        | United Kingdom | 153682        | 2      |
| 352        | United Kingdom | 147071        | 3      |
| 362        | United States  | 471293        | 1      |
| 354        | United States  | 432927        | 2      |
| 356        | United States  | 426712        | 3      |


**Top 10 selling products(bike) in 2022**
```sql
select 
s.productkey,
p.`ProductSubcategoryKey`, 
p.productprice, 
sum(s.orderquantity) 
from `product lookup` p join `adventureworks sales data` s
on p.productkey=s.productkey
where s.orderdate between '2022-01-01'and '2022-06-30' and p.`ProductSubcategoryKey` between 1 and 3
group by s.productkey,p.`ProductSubcategoryKey`, p.productprice
order by sum(s.orderquantity) desc
limit 10;
```
**Output**
| productkey | ProductSubcategoryKey | productprice | orderquantity) |
| ---------- | --------------------- | ------------ | -------------- |
| 358        | 1                     | 2049.0982    | 251            |
| 352        | 1                     | 2071.4196    | 248            |
| 360        | 1                     | 2049.0982    | 246            |
| 356        | 1                     | 2071.4196    | 244            |
| 606        | 2                     | 539.99       | 233            |
| 362        | 1                     | 2049.0982    | 227            |
| 354        | 1                     | 2071.4196    | 225            |
| 604        | 2                     | 539.99       | 206            |
| 605        | 2                     | 539.99       | 199            |
| 584        | 2                     | 539.99       | 188            |



**Products(bike) which have sales in 2020 but no sales from 2021**
```sql
select 
p.productkey,
p.`ProductSubcategoryKey`, 
p.productprice, 
sum(s.orderquantity) 
from `product lookup` p join `adventureworks sales data` s
on p.productkey=s.productkey
where year(s.orderdate)=2020  and p.`ProductSubcategoryKey` between 1 and 3 and p.productkey
not in (select distinct productkey from `adventureworks sales data` where year(orderdate)>2020)
group by p.productkey,p.`ProductSubcategoryKey`, p.productprice
order by sum(s.orderquantity) desc;
```
**Output**
**Number of Product:13**
| productkey | ProductSubcategoryKey | productprice | orderquantity) |
| ---------- | --------------------- | ------------ | -------------- |
| 312        | 2                     | 3578.27      | 179            |
| 310        | 2                     | 3578.27      | 169            |
| 313        | 2                     | 3578.27      | 168            |
| 314        | 2                     | 3578.27      | 157            |
| 311        | 2                     | 3578.27      | 139            |
| 351        | 1                     | 3374.99      | 36             |
| 350        | 1                     | 3374.99      | 31             |
| 344        | 1                     | 3399.99      | 29             |
| 348        | 1                     | 3374.99      | 26             |
| 349        | 1                     | 3374.99      | 26             |
| 345        | 1                     | 3399.99      | 25             |
| 346        | 1                     | 3399.99      | 24             |

**Old vs new product(bikes) sales comparison(after launching new products)**
```sql
WITH t1 AS (
    SELECT 
        ProductKey,
        ProductSubcategoryKey,
        MIN(OrderDate) AS min_date
    FROM (
        SELECT * 
        FROM `category` 
        WHERE ProductSubcategoryKey BETWEEN 1 AND 3
    ) AS sub
    GROUP BY 
        ProductKey, 
        ProductSubcategoryKey
),

t2 AS (
    SELECT 
        *,
        CASE 
            WHEN YEAR(min_date) = 2020 THEN 'old'
            ELSE 'new'
        END AS product_type
    FROM 
        t1
)

SELECT  
    t2.ProductSubcategoryKey,
    t2.product_type,
    COUNT(DISTINCT t2.ProductKey) AS product_count,
    AVG(s.ProductPrice) AS avg_price,
    SUM(s.OrderQuantity) AS total_order_quantity
FROM 
    t2 
JOIN 
    category s ON t2.ProductKey = s.ProductKey
WHERE 
    s.OrderDate BETWEEN '2021-07-01' AND '2022-06-30'
GROUP BY  
    t2.ProductSubcategoryKey,
    t2.product_type;
```
**Output**
| Subcategory name | product_type | Product Number | avg ProductPrice | OrderQuantity |
| ---------------- | ------------ | -------------- | ---------------- | ------------- |
| Mountain Bike    | new          | 14             | 667.1753877      | 1006          |
| Mountain Bike    | old          | 6              | 2060.047279      | 2426          |
| Road Bike        | new          | 8              | 993.342336       | 2333          |
| Road Bike        | old          | 10             | 1482.868838      | 1704          |
| Touring Bike     | new          | 22             | 1775.689576      | 2124          |

<img width="590" height="401" alt="image" src="https://github.com/user-attachments/assets/5dc5a281-3a7c-4679-aeb9-575369967e18" />


**Products which have sales in every year(2020-2022)(Bike)**
```sql
with t1 as(select productkey,ProductSubcategoryKey, `ProductPrice`,min(year(orderdate)) as min,max(year(orderdate)) as max, sum(orderquantity) as _sum
from (select * from `category` where `ProductSubcategoryKey` between 1 and 3)as t1
group by  productkey,ProductSubcategoryKey, `ProductPrice`)

select productkey,ProductSubcategoryKey, `ProductPrice`,_sum from t1
where min=2020 and max=2022;
```
**Output**
**Product Number: 16**
**Average Product Price:1766**
| productkey | ProductSubcategoryKey | ProductPrice | Order Quantity |
| ---------- | --------------------- | ------------ | -------------- |
| 371        | 2                     | 2181.5625    | 303            |
| 373        | 2                     | 2181.5625    | 263            |
| 354        | 1                     | 2071.4196    | 547            |
| 362        | 1                     | 2049.0982    | 606            |
| 385        | 2                     | 1000.4375    | 296            |
| 358        | 1                     | 2049.0982    | 569            |
| 377        | 2                     | 2181.5625    | 316            |
| 381        | 2                     | 1000.4375    | 264            |
| 379        | 2                     | 2181.5625    | 268            |
| 352        | 1                     | 2071.4196    | 586            |
| 375        | 2                     | 2181.5625    | 294            |
| 387        | 2                     | 1000.4375    | 281            |
| 360        | 1                     | 2049.0982    | 602            |
| 356        | 1                     | 2071.4196    | 571            |
| 383        | 2                     | 1000.4375    | 259            |
| 389        | 2                     | 1000.4375    | 258            |










