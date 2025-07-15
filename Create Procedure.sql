
-- Create a procedure to track the important matrics (use parameter to track matrics by year/month/overall)--
DELIMITER $$

CREATE PROCEDURE Overall_performance_by_month_year (
    IN in_year INT,
    IN in_month INT
)
BEGIN
    IF in_year IS NULL AND in_month IS NULL THEN
        -- No filter: return all sales
        SELECT count(`adventureworks sales data`.`ProductKey`)as order_number,sum(`adventureworks sales data`.OrderQuantity) as order_quantity,
        sum(`adventureworks sales data`.OrderQuantity*`product lookup`.`ProductPrice`) as revenue,
       (sum(`adventureworks sales data`.OrderQuantity*`product lookup`.`ProductPrice`)- sum(`adventureworks sales data`.OrderQuantity*`product lookup`.`ProductCost`))*100/sum(`adventureworks sales data`.OrderQuantity*`product lookup`.`ProductCost`)
       as profit_per, count(distinct `adventureworks sales data`.CustomerKey) as Customer_number from `product lookup` join `adventureworks sales data`
       on `product lookup`.`ProductKey`=`adventureworks sales data`.ProductKey;
    ELSE
        -- Apply filter if parameters are provided
        SELECT count(`adventureworks sales data`.`ProductKey`)as order_number,sum(`adventureworks sales data`.OrderQuantity) as order_quantity,
        sum(`adventureworks sales data`.OrderQuantity*`product lookup`.`ProductPrice`) as revenue,
       (sum(`adventureworks sales data`.OrderQuantity*`product lookup`.`ProductPrice`)- sum(`adventureworks sales data`.OrderQuantity*`product lookup`.`ProductCost`))*100/sum(`adventureworks sales data`.OrderQuantity*`product lookup`.`ProductCost`)
       as profit, count(distinct `adventureworks sales data`.CustomerKey) as Customer_number from `product lookup` join `adventureworks sales data`
       on `product lookup`.`ProductKey`=`adventureworks sales data`.ProductKey
        WHERE (in_year IS NULL OR YEAR(`adventureworks sales data`.`OrderDate`) = in_year)
          AND (in_month IS NULL OR MONTH(`adventureworks sales data`.`OrderDate`) = in_month);
    END IF;
END $$

DELIMITER ;

call  Overall_performance_by_month_year(null,null)
