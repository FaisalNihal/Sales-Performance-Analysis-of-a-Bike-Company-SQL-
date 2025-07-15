use sales_analysis;

-- Customer table Inspection --
select customerKey,count(customerkey) from ` customer lookup` 
group by customerKey
order by count(customerkey) desc;  -- Check the presence of any duplicate value in primary column --

alter table ` customer lookup` -- Remove unwanted columns --
drop column `MaritalStatus`,drop column `TotalChildren`, drop column `EducationLevel`, drop column `HomeOwner`;
select `BirthDate`,`Gender`,`AnnualIncome`,`Occupation` from ` customer lookup` 
where `BirthDate`is null or`Gender`is null or `AnnualIncome`is null or`Occupation`is null; -- Check the presence of any null value in other columns --

-- Fact Table Inspection --
select count(orderdate) from `adventureworks sales data` ; -- check the presence of duplicate records -- 
select count(*) from (select distinct * from `adventureworks sales data`) as t1;
select `ProductKey`,`CustomerKey`,`TerritoryKey`,`OrderLineItem`,`OrderQuantity` from `adventureworks sales data`
where `ProductKey`is null or `CustomerKey`is null or `TerritoryKey`is null or`OrderLineItem`is null or `OrderQuantity` is null;
delete from `adventureworks sales data` 
where `OrderQuantity` is null;

-- Product table inspection--
select productKey,count(productkey) from `product lookup` -- Check the presence of duplicate value in primary column --
group by productKey
order by count(productkey) desc;





