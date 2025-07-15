use `sales_analysis`;

-- Create index on frequently used column of the dimension table(product_lookup)
create index Product_key on
`product lookup`(`ProductKey`);
-- Product category wise order number, order quantity, revenue and profit%--
create table Category_summary as
select p.`CategoryName`,count(c.OrderQuantity) as order_number,sum(c.OrderQuantity) as order_quantity,
round(sum(c.OrderQuantity*c.ProductPrice),0) as revenue, 
round((sum(c.OrderQuantity*c.ProductPrice)-sum(c.OrderQuantity*c.ProductCost))*100/sum(c.OrderQuantity*c.ProductCost),0)
as profit_per  from category c right join `product categories lookup` p   
on c.ProductCategoryKey=p.ProductCategoryKey
group by  p.`CategoryName`;

select * from Category_summary;


create table  category as
with t1 as (select`adventureworks sales data`.ProductKey,`adventureworks sales data`.orderdate,`product lookup`.`ProductSubcategoryKey`,`adventureworks sales data`.OrderQuantity,
`product lookup`.ProductPrice,`product lookup`.ProductCost,`adventureworks sales data`.customerkey from `product lookup` join `adventureworks sales data`
on `product lookup`.productkey=`adventureworks sales data`.productkey)
select t1.*, `product subcategories lookup`.ProductCategoryKey,t1.orderquantity*t1.productprice as rev,
t1.orderquantity*t1.productcost as total_cost from t1 join  `product subcategories lookup`
on t1.`ProductSubcategoryKey`= `product subcategories lookup`.ProductSubcategoryKey;





-- Sales Analysis of main product(bikes)--

  select p.`SubcategoryName`,count(distinct c.productkey), year(c.orderdate) as year_,avg(c.`ProductPrice`),sum(c.OrderQuantity) as order_quantity,
round(sum(c.OrderQuantity*c.ProductPrice),0) as revenue, sum(c.OrderQuantity) /count(distinct month(c.orderdate))as  order_per_month,
round((sum(c.OrderQuantity*c.ProductPrice)-sum(c.OrderQuantity*c.ProductCost))*100/sum(c.OrderQuantity*c.ProductCost),0)
as profit_per  from category c  join `product subcategories lookup` p   
on c.`ProductSubcategoryKey`=p.`ProductSubcategoryKey`
where c.`ProductCategoryKey`=1 
group by  p.`SubcategoryName`,year(c.orderdate);

-- Products which have no sales record(Bikes) --
select productkey,`ProductSubcategoryKey`,`ProductPrice` from `product lookup`
where `ProductSubcategoryKey` between 1 and 3 and productkey not in (select distinct productkey from `adventureworks sales data`);

-- Revenue per order value in different years (bike)
select year(orderdate), round(sum(`ProductPrice`*`OrderQuantity`),0) as revenue,count(productkey) as total_order,
count(distinct productkey) as total_product,round(sum(`ProductPrice`*`OrderQuantity`),0)/count(productkey) as rev_per_order,
(sum(rev)-sum(total_cost))*100/sum(total_cost) as profit
    from `category`
where `ProductCategoryKey`=1
group by year(orderdate);

-- YoY change of Order per Month change for low price bikes --
with t1 as(select  
p.`SubcategoryName`, 
year(c.orderdate) as year_,
sum(c.OrderQuantity) as order_quantity,
sum(c.OrderQuantity) /count(distinct month(c.orderdate))as  order_per_month
from category c  join `product subcategories lookup` p   
on c.`ProductSubcategoryKey`=p.`ProductSubcategoryKey`
where c.`ProductCategoryKey`=1 and c.`ProductPrice`<1500
group by  p.`SubcategoryName`,year(c.orderdate))
select *,lag(order_per_month) over (partition by `SubcategoryName` order by year_) as previous,
order_per_month-lag(order_per_month) over (partition by `SubcategoryName` order by year_) as YOY
from t1;

-- YoY change of Order per Month change for high price bikes --
with t1 as(select  
p.`SubcategoryName`, 
year(c.orderdate) as year_,
sum(c.OrderQuantity) as order_quantity,
sum(c.OrderQuantity) /count(distinct month(c.orderdate))as  order_per_month
from category c  join `product subcategories lookup` p   
on c.`ProductSubcategoryKey`=p.`ProductSubcategoryKey`
where c.`ProductCategoryKey`=1 and c.`ProductPrice`>2000
group by  p.`SubcategoryName`,year(c.orderdate))
select *,lag(order_per_month) over (partition by `SubcategoryName` order by year_) as previous,
order_per_month-lag(order_per_month) over (partition by `SubcategoryName` order by year_) as YOY
from t1;


-- Top 3 selling products(bike) of every country --
with t3 as(with t2 as (with t1 as(select `adventureworks sales data`.productkey,`product lookup`.`ProductSubcategoryKey`, 
(`adventureworks sales data`.orderquantity*`product lookup`.productprice) as revenue,
`adventureworks sales data`.`TerritoryKey` from `product lookup` join `adventureworks sales data`
on `product lookup`.productkey=`adventureworks sales data`.productkey
where `product lookup`.`ProductSubcategoryKey` between 1 and 3)
select t1.productkey, ` territory lookup`.`Country`,round(sum(t1.revenue),0) as total_revenue from t1 join ` territory lookup`
on t1.territorykey=` territory lookup`.`SalesTerritoryKey`
group by t1.productkey, ` territory lookup`.`Country`)
select productkey, country, total_revenue,rank() over (partition by country order by total_revenue desc) as _rank_ from t2)
select productkey, country, total_revenue,_rank_ from t3
where _rank_<=3;

-- Top 10 selling products(bike) in 2022--
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

-- Products(bike) which have sales in 2020 but no sales from 2021--
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

-- Old vs new product(bikes) sales comparison(after launching new products)--
with t2 as(with t1 as(select`ProductKey`,`ProductSubcategoryKey`,min(orderdate) as min from (select * from `category` where `ProductSubcategoryKey` between 1 and 3)as t1
group by `ProductKey`,`ProductSubcategoryKey`)
select *, 
case
   when year(min)=2020 then "old"
   else "new" end as product_type
from t1)
select  t2.`ProductSubcategoryKey`,t2.product_type,count( distinct t2.productkey), avg(`ProductPrice`),sum(`OrderQuantity`)
from t2 join category s on t2.productkey=s.productkey
where s.orderdate between '2021-07-01' and '2022-06-30'
group by  t2.`ProductSubcategoryKey`,product_type;


-- Products which have sales in every year(2020-2022)--
with t1 as(select productkey,ProductSubcategoryKey, `ProductPrice`,min(year(orderdate)) as min,max(year(orderdate)) as max, sum(orderquantity) as _sum
from (select * from `category` where `ProductSubcategoryKey` between 1 and 3)as t1
group by  productkey,ProductSubcategoryKey, `ProductPrice`)

select productkey,ProductSubcategoryKey, `ProductPrice`,_sum from t1
where min=2020 and max=2022













