use `sales_analysis`;

-- Sales performance of products (Accessories)
select p.`SubcategoryName`,p.`ProductSubcategoryKey`,c.productkey,c.productprice, count(c.customerkey) as total_order,  sum(orderquantity)/count(c.customerkey) as total_quantity,
round(sum(c.rev),0) as total_revenue, (sum(c.rev)-sum(c.total_cost))*100/sum(c.total_cost) as profit_per
from `product subcategories lookup` p  join (select * from category  where `ProductSubcategoryKey` not in (1,2,3)) as c
on p.`ProductSubcategoryKey`=c.`ProductSubcategoryKey`
group by p.`SubcategoryName`,p.`ProductSubcategoryKey`,c.productkey,c.productprice;

-- Number of products and unsold Products in each categories of accessories --
with t1 as(select p.`CategoryName`,p.`ProductCategoryKey`, count(a.`ProductKey`) as total_pro from `product categories lookup` p join `product subcategories lookup` s
on p.`ProductCategoryKey`=s.`ProductCategoryKey` join `product lookup` a
on s.`ProductSubcategoryKey`=a.`ProductSubcategoryKey`
where a.`ProductSubcategoryKey`not in (1,2,3)
group by p.`CategoryName`,p.`ProductCategoryKey`),
t2 as (select `ProductCategoryKey`,count(distinct productkey)  as sold_num_of_pro ,sum(orderquantity) as total_quantity,round(sum(rev),0) as total_revenue
from category group by  `ProductCategoryKey`)
select t1.*,
case
     when t2.sold_num_of_pro is null then 0
     else t2.sold_num_of_pro end as sold_num,
case
   when t2.sold_num_of_pro is null then t1.total_pro
   else (t1.total_pro- t2.sold_num_of_pro) end as unsold_pro ,t2.t2.total_quantity,t2. total_revenue from t1 left join t2
on t1.`ProductCategoryKey`=t2.`ProductCategoryKey`;

-- Year Wise sales performance of Accessories --
select extract(year from orderdate), count(c.customerkey) as total_order,  sum(orderquantity)/count(distinct month(orderdate)) as quantity_per_month,
round(sum(c.rev),0) as total_revenue, (sum(c.rev)-sum(c.total_cost))*100/sum(c.total_cost) as profit_per
from (select * from category  where `ProductSubcategoryKey` not in (1,2,3)) as c
group by extract(year from orderdate);



-- Accessories purchase amount relation with bike price--
with t3 as(with t1 as(select s.customerkey, avg(p.productprice) as price ,sum(s.orderquantity) as bike_sell,max(orderdate) as _max 
from `product lookup` p join `adventureworks sales data` s
on p.productkey=s.productkey
where p.`ProductSubcategoryKey` between 1 and 3
group by s.customerkey),
t2 as (select customerkey, sum(orderquantity) as order_quantity,sum(orderquantity*productprice) as revenue from category where `ProductSubcategoryKey`not in (1,2,3)
group by customerkey)
select t1.*,t2.order_quantity,t2.revenue,
case
when price<1000 then 'low'
when price between 1000 and 2000 then 'mid'
when price>2000 then 'high' end as price_range
  from t1 left join t2 on t1.customerkey=t2.customerkey
where order_quantity is not null)
select price_range as bike_price_range, avg(order_quantity) as accessory_quantity_per_order,avg(revenue) as accessory_revenue_per_order from t3
where year(_max)=2022
group by price_range;
  
-- Number of products in each accessories and their sales amount --
with t3 as(with t1 as(select s.`SubcategoryName`,s.`ProductSubcategoryKey`,count(p.`ProductKey`) as total_products from `product subcategories lookup` s join `product lookup` p
on s.`ProductSubcategoryKey`=p.`ProductSubcategoryKey`
where p.`ProductSubcategoryKey` not in (1,2,3)
group by s.`SubcategoryName`,s.`ProductSubcategoryKey`),
t2 as(select p.`SubcategoryName`,p.`ProductSubcategoryKey`,count(distinct c.productkey) as pro_num, count(c.customerkey) as total_order,  sum(orderquantity) as quantity,
round(sum(c.rev),0) as total_revenue, (sum(c.rev)-sum(c.total_cost))*100/sum(c.total_cost) as profit_per
from `product subcategories lookup` p  join (select * from category  where `ProductSubcategoryKey` not in (1,2,3)) as c
on p.`ProductSubcategoryKey`=c.`ProductSubcategoryKey`
group by p.`SubcategoryName`,p.`ProductSubcategoryKey`)
select t1.*,t2.pro_num,t2.total_order,t2.quantity,t2.total_revenue,t2.profit_per from t1 left join t2 
on t1.`ProductSubcategoryKey`=t2.`ProductSubcategoryKey`)
select subcategoryname,total_order/pro_num as order_per_pro,total_products,(total_products-pro_num) as unsold from t3;

-- Order quantity per order by products(accessories) and price_range --
with t1 as(select p.`SubcategoryName`,p.`ProductSubcategoryKey`,c.productkey,
case
when c.productprice<20 then 'low'
when c.productprice between 20 and 50 then 'mid'
else 'high' end as price_range, 
count(c.customerkey) as total_order,  sum(orderquantity)/count(c.customerkey) as total_quantity,
round(sum(c.rev),0) as total_revenue, (sum(c.rev)-sum(c.total_cost))*100/sum(c.total_cost) as profit_per
from `product subcategories lookup` p  join (select * from category  where `ProductSubcategoryKey` not in (1,2,3)) as c
on p.`ProductSubcategoryKey`=c.`ProductSubcategoryKey`
group by p.`SubcategoryName`,p.`ProductSubcategoryKey`,c.productkey,c.productprice)
select `SubcategoryName`,price_range,avg(total_quantity) from t1
group by `SubcategoryName`,price_range;

-- top 5 products by sales quantity--
select c.productkey,s.`SubcategoryName`,c.productprice, sum(c.orderquantity) from (select * from category
where `ProductSubcategoryKey` not in (1,2,3)) as c join `product subcategories lookup` s
on c. `ProductSubcategoryKey`=s.`ProductSubcategoryKey`
group by productkey,`SubcategoryName`,productprice
order by sum(orderquantity) desc 
limit 5;

-- bottom 5 products by sales quantity--
select c.productkey,s.`SubcategoryName`,c.productprice, sum(c.orderquantity) from (select * from category
where `ProductSubcategoryKey` not in (1,2,3)) as c join `product subcategories lookup` s
on c. `ProductSubcategoryKey`=s.`ProductSubcategoryKey`
group by productkey,`SubcategoryName`,productprice
order by sum(orderquantity) asc
limit 5

