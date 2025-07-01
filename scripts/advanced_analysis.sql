--Change over time Analysis

--1.Analyse sales performance over time

--Trends over Year

select 
Year(order_date) as order_year,
Month(order_date) as order_month,
sum(sales_amount) as Sales,
count(distinct customer_key) as total_customers,
sum(quantity) as total_quantity
from dw1.dbo.[gold.fact_sales]
where Year(order_date) is not null
group by Year(order_date),Month(order_date)
order by Year(order_date),Month(order_date)


--2.Trends over Month
select 
Month(order_date) as order_month,
sum(sales_amount) as Sales,
count(distinct customer_key) as total_customers,
sum(quantity) as total_quantity
from dw1.dbo.[gold.fact_sales]
where Month(order_date) is not null
group by Month(order_date)
order by Month(order_date)


--Cumulative Analysis
--1.Calculate the total sales per month and the running total of the sales over time
select order_month,
total_sales,
sum(total_sales) over(order by order_month) as running_total,
Avg(total_sales) over(order by order_month) as moving_avg
from(
select 
Datetrunc(month,order_date) as order_month,
sum(sales_amount) as total_sales,
avg(sales_amount) as avg_sales
from dw1.dbo.[gold.fact_sales]
where Datetrunc(month,order_date) is not null
group by Datetrunc(month,order_date)) t


--------
select order_month,
total_sales,
sum(total_sales) over(order by order_month) as running_total,
Avg(total_sales) over(order by order_month) as moving_avg

from(
select 
month(order_date) as order_month,
sum(sales_amount) as total_sales,
avg(sales_amount) as avg_sales
from gold.fact_sales
where month(order_date)  is not null
group by month(order_date) ) t


-- 3.Performance Analysis

/* Analyse the yearly performance of the products by comparing their sales to both 
    the average sales performance of the product and the previous year's sales*/

 with yearly_ordered as
 (
	 select 
	 year(s.order_date) as order_year,
	 p.product_name as product_name,
	 sum(s.sales_amount) as current_sales
	 from dw1.dbo.[gold.fact_sales] s
	 left join dw1.dbo.[gold.dim_products] p
	 on s.product_key = p.product_key
	 where s.order_date is not null
	 group by year(s.order_date), p.product_name
 )

	 select 
		 order_year,
		 product_name,
		 current_sales,
		 avg(current_sales) over(partition by product_name ) as avg_sales,
		 current_sales - avg(current_sales) over(partition by product_name) as diff_sales,
		 case when current_sales  - avg(current_sales) over(partition by product_name) >0 then 'Above Avg'
		      when current_sales  - avg(current_sales) over(partition by product_name) <0 then 'Below Avg'
			  else 'Avg'
		 end avg_change,

		 --Year over year Analysis

		 lag(current_sales) over(partition by product_name order by order_year) as py_sales,
		 current_sales -  lag(current_sales) over(partition by product_name order by order_year)  as py_diff,
		 case when current_sales -  lag(current_sales) over(partition by product_name order by order_year) >0 then 'Increase'
		      when current_sales -  lag(current_sales) over(partition by product_name order by order_year) <0 then 'Decrease'
			  else 'No Change'
		 end py_change
	 from yearly_ordered
	 order by order_year,product_name

--Part to whole Analysis
/*Which categories contribute the most to overall sales*/
with category_sales as (
select 
p.category as category ,
sum(f.sales_amount) as total_sales
from dw1.dbo.[gold.fact_sales] f
left join dw1.dbo.[gold.dim_products] p
on p.product_key =f.product_key
group by p.category)

select 
category,
total_sales,
sum(total_sales) over() as overall_sales,
concat(round((cast(total_sales as float)/sum(total_sales) over() *100),2),'%') as percentage_of_sales
from category_sales
order by total_sales desc



--Data segmentation

/* Segment products into cost ranges and
  count how many products fall into each category*/

with product_segmentation as(
select product_key,
product_name,
cost,
case when cost<100 then 'Beloww 100'
     when cost between 100 and 500 then '100-500'
	 when cost between 500 and 1000 then '500-1000'
	 else 'Above 1000'
end cost_range
from
dw1.dbo.[gold.dim_products])

select cost_range,
count(product_key) as total_products
from product_segmentation
group by cost_range
order by total_products desc


/* Group Customers into three segemnts based on their spendidng behaviour:
 --VIP : Customers with atleast 12 months of history and  spending more than 5,000
 --Regular: Customers with atleast 12 months of history but spending 5,000 or less
 --New: Customers with a lifspan of less than 12 months.
 and find the total no of customers of each group. */

 with customer_spending as (
 select 
 c.customer_key,
 sum(f.sales_amount) as total_sales,
 min(f.order_date) as first_order,
 max(f.order_date) as last_order,
 Datediff(month,min(f.order_date),max(f.order_date)) as lifespan
 from dw1.dbo.[gold.fact_sales] f
 left join dw1.dbo.[gold.dim_customers] c
 on f.customer_key = c.customer_key
 group by c.customer_key)


 select customer_segment,
 count(customer_key) as total_customer
 from(
	 select 
	 customer_key,
	 total_sales,
	 lifespan,
	 case when lifespan >=12 and total_sales>5000 then 'VIP'
		  when lifespan >=12 and total_sales<=5000 then 'Regular'
		  else 'New'
	end customer_segment
	from
	customer_spending ) t
group by customer_segment
order by total_customer desc
