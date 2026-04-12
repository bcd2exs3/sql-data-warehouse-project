
/*
===============================================================================
Database Exploration
===============================================================================
Purpose:
    - To explore the structure of the database, including the list of tables and their schemas.
    - To inspect the columns and metadata for specific tables.

Table Used:
    - INFORMATION_SCHEMA.TABLES
    - INFORMATION_SCHEMA.COLUMNS
===============================================================================
*/

-- Retrieve a list of all tables in the database
SELECT	
	*
FROM INFORMATION_SCHEMA.TABLES

-- Retrieve all columns for a specific table (dim_customers)
SELECT
	*
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers'

/*
===============================================================================
Dimensions Exploration
===============================================================================
Purpose:
    - To explore the structure of dimension tables.
	
SQL Functions Used:
    - DISTINCT
    - ORDER BY
===============================================================================
*/

-- Retrieve a list of unique countries from which customers originate
SELECT 
	DISTINCT country
FROM gold.dim_customers

-- Retrieve a list of unique categories, subcategories, and products
SELECT 
	DISTINCT category,
	sub_category,
	product_name
FROM gold.dim_products
ORDER BY 1,2,3

/*
===============================================================================
Date Range Exploration 
===============================================================================
Purpose:
    - To determine the temporal boundaries of key data points.
    - To understand the range of historical data.

SQL Functions Used:
    - MIN(), MAX(), DATEDIFF()
===============================================================================
*/

-- Determine the first and last order date and the total duration in months
SELECT 
*,
DATEDIFF(YEAR, first_order, last_order) AS order_range_years
FROM(SELECT
	customer_key,
	MIN(order_date)	AS first_order,
	MAX(order_date)	AS last_order
FROM gold.fact_sales
GROUP BY customer_key
)t

-- Find the youngest and oldest customer based on birthdate
SELECT
	DATEDIFF(YEAR, MAX(birthdate), GETDATE())	AS youngest,
	DATEDIFF(YEAR, MIN(birthdate), GETDATE())	AS oldest
FROM gold.dim_customers

/*
===============================================================================
Measures Exploration (Key Metrics)
===============================================================================
Purpose:
    - To calculate aggregated metrics (e.g., totals, averages) for quick insights.
    - To identify overall trends or spot anomalies.

SQL Functions Used:
    - COUNT(), SUM(), AVG()
===============================================================================
*/

-- Find the Total Sales
SELECT	'Total Sales'		AS measure_name, SUM(sale_amount)				AS measure_value FROM gold.fact_sales
UNION ALL
-- Find how many items are sold
SELECT	'Total Quantity'	AS measure_name, SUM(quantity)					AS measure_value FROM gold.fact_sales
UNION ALL
-- Find the average selling price
SELECT	'Average Price'		AS measure_name, AVG(price)						AS measure_value FROM gold.fact_sales
UNION ALL
-- Find the Total number of Orders
SELECT	'Total Orders'		AS measure_name, COUNT(DISTINCT order_number)	AS measure_value FROM gold.fact_sales
UNION ALL
-- Find the total number of customers that has placed an order
SELECT	'Total Customers With Orders'	AS measure_name, COUNT(DISTINCT customer_key)	AS measure_value FROM gold.fact_sales
UNION ALL
-- Find the total number of products
SELECT 'Total Products'		AS measure_name, COUNT(product_key)				AS nr_products	FROM gold.dim_products
UNION ALL
-- Find the total number of customers
SELECT 'Total Customers'	AS measure_name, COUNT(customer_key)			AS nr_customers FROM gold.dim_customers

/*
===============================================================================
Magnitude Analysis
===============================================================================
Purpose:
    - To quantify data and group results by specific dimensions.
    - For understanding data distribution across categories.

SQL Functions Used:
    - Aggregate Functions: SUM(), COUNT(), AVG()
    - GROUP BY, ORDER BY
===============================================================================
*/

-- Find total customers by countries
SELECT 
	country, 
	COUNT(customer_key) AS 'Total Customers/Country'
FROM gold.dim_customers 
GROUP BY country
ORDER BY 2 DESC

-- Find total customers by gender
SELECT 
	gender, 
	COUNT(gender) AS 'Total Customers/Gender'
FROM gold.dim_customers 
GROUP BY gender
ORDER BY 2 DESC

-- Find total products by category
SELECT 
	category, 
	COUNT(product_key) AS 'Total Products/Category'
FROM gold.dim_products 
GROUP BY category
ORDER BY 2 DESC

-- What is the average costs in each category?
SELECT 
	category, 
	AVG(cost) AS 'Average Cost/Category'
FROM gold.dim_products 
GROUP BY category
ORDER BY 2 DESC

-- What is the total revenue generated for each category?
SELECT 
	dp.category,
	SUM(sale_amount) AS 'Total Revenue/Category'
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products dp
ON fs.product_key = dp.product_key
GROUP BY dp.category
ORDER BY 2 DESC

-- What is the total revenue generated by each customer?
SELECT 
	dc.customer_key,
	dc.first_name,
	dc.last_name,
	SUM(sale_amount) AS 'Total Revenue/Customer'
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers dc
ON fs.customer_key = dc.customer_key
GROUP BY dc.customer_key, dc.first_name, dc.last_name
ORDER BY 4 DESC

-- What is the distribution of sold items across countries?
SELECT 
	dc.country,
	SUM(quantity) AS 'Total Quantity/Country'
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers dc
ON fs.customer_key = dc.customer_key
GROUP BY dc.country
ORDER BY 2 DESC

/*
===============================================================================
Ranking Analysis
===============================================================================
Purpose:
    - To rank items (e.g., products, customers) based on performance or other metrics.
    - To identify top performers or laggards.

SQL Functions Used:
    - Window Ranking Functions: RANK(), DENSE_RANK(), ROW_NUMBER(), TOP
    - Clauses: GROUP BY, ORDER BY
===============================================================================
*/

-- Which 5 products Generating the Highest Revenue?
-- Simple Ranking
SELECT TOP 5
	dp.product_name,
	SUM(fs.sale_amount) AS 'Best Performing Product'
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products dp
ON fs.product_key = dp.product_key
GROUP BY dp.product_name
ORDER BY 2 DESC

-- What are the 5 worst-performing products in terms of sales?
SELECT TOP 5
	dp.product_name,
	SUM(fs.sale_amount) AS 'Worst Performing Product'
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products dp
ON fs.product_key = dp.product_key
GROUP BY dp.product_name
ORDER BY 2 ASC

-- Complex but Flexibly Ranking Using Window Functions
SELECT
	*
FROM(SELECT 
	dp.product_name,
	ROW_NUMBER() OVER(ORDER BY SUM(fs.sale_amount) DESC) AS rank_products
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products dp
ON fs.product_key = dp.product_key
GROUP BY dp.product_name
)t WHERE rank_products <= 5

-- Find the top 10 customers who have generated the highest revenue
SELECT TOP 10
	dc.customer_key,
	dc.first_name,
	dc.last_name,
	SUM(sale_amount) AS 'Top 10 Customers/Revenue'
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers dc
ON fs.customer_key = dc.customer_key
GROUP BY dc.customer_key, dc.first_name, dc.last_name
ORDER BY 4 DESC

-- The 3 customers with the fewest orders placed
SELECT TOP 3
	dc.customer_key,
	dc.first_name,
	dc.last_name,
	COUNT(DISTINCT order_number) AS 'Least Places Orders/Customer'
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers dc
ON fs.customer_key = dc.customer_key
GROUP BY dc.customer_key, dc.first_name, dc.last_name
ORDER BY 4 ASC