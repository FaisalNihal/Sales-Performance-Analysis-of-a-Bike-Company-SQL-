use`sales_analysis`;

 select max(`AnnualIncome`),min(`AnnualIncome`) from ` customer lookup`;
 select distinct`AnnualIncome`,count(`CustomerKey`)over (partition by `AnnualIncome`) from ` customer lookup`;

select count(`CustomerKey`) as Total_customer from ` customer lookup`;

with t1 as(select extract(year from orderdate) as year_, `CustomerKey`,count(`OrderDate`),row_number()over(partition by `CustomerKey`order by extract(year from orderdate))  
as row_ from`adventureworks sales data`
group by extract(year from orderdate), `CustomerKey`)
select year_,count(customerkey) from t1
where row_=1
group by year_;

create table Final_customer as
with t2 as (select `_customer_`.CustomerKey,round(sum(`adventureworks sales data`.orderquantity*`product lookup`.`ProductPrice`),0)as revenue from `_customer_` join `adventureworks sales data`
on `_customer_`.`CustomerKey`=`adventureworks sales data`.`CustomerKey` join `product lookup`
on `adventureworks sales data`.productkey=`product lookup`.productkey
where `product lookup`.`ProductSubcategoryKey` between 1 and 3
group by `_customer_`.CustomerKey)
select `_customer_`.*,t2.revenue from t2 right join `_customer_`
on t2.CustomerKey=`_customer_`.customerkey;

-- Number of customer and revenue per customer by income_category --
select income_category,count(customerkey) as num_customer, sum(revenue)/count(customerkey) as rev_per_cust
from `final_customer`
where ordernumber<>0
group by income_category;

-- Number of customer who have no sales record (might be purchased product before the given time period)--
 select count(customerkey)*100/(select count(customerkey) from `final_customer`) from `final_customer`
where ordernumber=0;

select * from `final_customer`;

-- Customers who buy our main product(Bike) but didn't purchase any accessories--

	with t3 as(with t1 as(select` customer lookup`.`CustomerKey`, sum(`adventureworks sales data`.orderquantity)as sum_,max(`adventureworks sales data`.orderdate) 
    as _max from ` customer lookup`left join `adventureworks sales data` on ` customer lookup`.customerkey=`adventureworks sales data`.customerkey  join `product lookup`
    on `adventureworks sales data`.productkey=`product lookup`.productkey where `product lookup`.`ProductSubcategoryKey` in (1,2,3)  group by ` customer lookup`.`CustomerKey`),  
    t2 as(select` customer lookup`.`CustomerKey`, sum(`adventureworks sales data`.orderquantity)as Acce_sum_,max(`adventureworks sales data`.orderdate) as _max from ` customer lookup`
    left join `adventureworks sales data` on ` customer lookup`.customerkey=`adventureworks sales data`.customerkey  join `product lookup` 
    
    on `adventureworks sales data`.productkey=`product lookup`.productkey where `product lookup`.`ProductSubcategoryKey`not in (1,2,3)  group by ` customer lookup`.`CustomerKey`) 
    select t1.*,t2.Acce_sum_ from t1 left join t2  on t1.customerkey=t2.customerkey) select customerkey from t3  where Acce_sum_ is null;	

-- Top 3 Customers of Every Country--
with t3 as(with t2 as (with t1 as(select `adventureworks sales data`.customerkey, (`adventureworks sales data`.orderquantity*`product lookup`.productprice) as revenue,
`adventureworks sales data`.`TerritoryKey` from `product lookup` join `adventureworks sales data`
on `product lookup`.productkey=`adventureworks sales data`.productkey)
select t1.customerkey, ` territory lookup`.`Country`,round(sum(t1.revenue),0) as total_revenue from t1 join ` territory lookup`
on t1.territorykey=` territory lookup`.`SalesTerritoryKey`
group by t1.customerkey, ` territory lookup`.`Country`)
select customerkey, country, total_revenue,rank() over (partition by country order by total_revenue desc) as _rank_ from t2)
select customerkey, country, total_revenue,_rank_ from t3
where _rank_<=3;

-- Create a view to show customers sells quantity of bike and accessories in separate columns--
create view sales_amount_by_customer as

select * from `sales_amount_by_customer`;



-- List of retail customers of Accessories--
 with t1 as (select `customerkey`,`acce_sum`,`max`,datediff((select max(orderdate) from`adventureworks sales data`),`max`) _last from `sales_amount_by_customer`
where `acce_sum`>20 and _sum is null)
select count(`customerkey`) as retail_customer_number from t1;

-- List of retail customers who has high chance to become churned--
with t1 as(select `customerkey`,`acce_sum`,`max`,datediff((select max(orderdate) from`adventureworks sales data`),`max`)as  _last from `sales_amount_by_customer`
where `acce_sum`>20 and _sum is null)
select `customerkey`,`acce_sum` from t1 
where _last>60;

-- List of customers who buy at least one bike and 10 accessories --
select `customerkey`,`acce_sum`,`max`,datediff((select max(orderdate) from`adventureworks sales data`),`max`) _last from `sales_amount_by_customer`
where `acce_sum`>=10 and _sum>=1;

-- List of customers who buy more than 2 bikes and their last purchase is within 100 days and overall purchase duration is more then 300 days--
with t1 as(select s.customerkey, sum(s.orderquantity) as orderquantity, sum(s.orderquantity*p.`ProductPrice`)/sum(s.orderquantity) as revenue_per_order ,
min(s.orderdate) as min_,datediff((select max(orderdate) from `adventureworks sales data`),max(s.orderdate)) as _last,
datediff(max(s.orderdate),min(s.orderdate))as _duration
from `product lookup` p join `adventureworks sales data` s
on p.productkey=s.productkey
where p.`ProductSubcategoryKey` between 1 and 3
group by   s.customerkey
having sum(s.orderquantity)>2)
select customerkey,orderquantity,min_,_last,_duration from  t1
where _last<100 and _duration>300;

-- find customers who place multiple bike order in the same day--
select s.customerkey, s.orderdate,s.orderquantity, row_number()over (partition by s.customerkey, s.orderdate) from `adventureworks sales data`s
join `product lookup` p on s.productkey=p.productkey
where p.`ProductSubcategoryKey`between 1 and 3;

-- Number of new customers of each income category in 2022--
select f.`income_category`,count(distinct s.`CustomerKey`) from `final_customer` f join `adventureworks sales data`s
on f.customerkey=s.customerkey 
where year(s.orderdate)=2022 and s.`CustomerKey` not in (select distinct customerkey from`adventureworks sales data`
where year(orderdate)<2022)
group by f.`income_category`;

                          
















