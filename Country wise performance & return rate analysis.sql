
-- Product Subcategorywise return_rate--
with t3 as(with t1 as(select c.`ProductSubcategoryKey`,sum(r.`Returnquantity`) as return_number from `rturn_number` r
join `product lookup` c on r.productkey=c.productkey 
group by c.`ProductSubcategoryKey`),
t2 as (select c.`ProductSubcategoryKey`,sum(a.orderquantity) as order_number from category a
join `product lookup` c on a.productkey=c.productkey 
group by c.`ProductSubcategoryKey`)
select t1.`ProductSubcategoryKey`,t2.order_number, t1.return_number*100/t2.order_number as return_rate
 from t1 join t2 on t1.`ProductSubcategoryKey`=t2.`ProductSubcategoryKey`)
 select s.`ProductcategoryKey`,sum(t3.order_number),avg(t3.return_rate) from `product subcategories lookup` s
 join t3 on s.`ProductSubcategoryKey`=t3.`ProductSubcategoryKey`
 group by s.`ProductCategoryKey`;

-- Country wise sales performance--
select t.country,count(s.productkey),sum(s.orderquantity), sum(s.orderquantity* p.productprice) as revenue ,avg(p.productprice),
(sum(s.orderquantity* p.productprice)-sum(s.orderquantity* p.productcost))*100/sum(s.orderquantity* p.productcost) as profit from ` territory lookup` t
join `adventureworks sales data`s on t.`SalesTerritoryKey`=s.`TerritoryKey` join `product lookup` p on
s.productkey=p.productkey

group by  t.country;


-- Country wise product return rate
with t1 as(select t.country,count(r.`Returndate`) as return_number from `rturn_number` r
join ` territory lookup` t on r.`TerritoryKey`=t.`SalesTerritoryKey` 
group by t.country),
t2 as (select t.country,sum(a.orderquantity) as order_number from `adventureworks sales data` a
join ` territory lookup` t on a.`TerritoryKey`=t. `SalesTerritoryKey` 
group by t.country)
select t1.country,t2.order_number, t1.return_number*100/t2.order_number as return_rate
 from t1 join t2 on t1.country=t2.country;
 
 -- Return rate over time --
 with t1 as (select extract(year from orderdate) as _year ,count(productkey) as order_number from `category`
 group by extract(year from orderdate)),
 t2 as (select extract(year from `ReturnDate`) as _year ,count(productkey) as return_number from `rturn_number`
 group by extract(year from returndate))
 select t1._year,t1.order_number,t2.return_number*100/t1.order_number as return_rate from t1 join t2
 on t1._year=t2._year