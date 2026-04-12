/*
===============================================================================
Change Over Time Analysis
===============================================================================
Purpose:
    - To track trends, growth, and changes in key metrics over time.
    - For time-series analysis and identifying seasonality.
    - To measure growth or decline over specific periods.

SQL Functions Used:
    - Date Functions: DATEPART(), DATETRUNC(), FORMAT()
    - Aggregate Functions: SUM(), COUNT(), AVG()
===============================================================================
*/

-- Analyse sales performance over time
-- Quick Date Functions
SELECT
	DATETRUNC(MONTH, order_date) AS order_date,
	SUM(sale_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity)	AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY 1

-- DATETRUNC()
SELECT
	DATETRUNC(MONTH, order_date) AS order_date,
	SUM(sale_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)

-- FORMAT()
SELECT
    FORMAT(order_date, 'yyyy-MMM') AS order_date,
    SUM(sale_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY 1;

/*
===============================================================================
Cumulative Analysis
===============================================================================
Purpose:
    - To calculate running totals or moving averages for key metrics.
    - To track performance over time cumulatively.
    - Useful for growth analysis or identifying long-term trends.

SQL Functions Used:
    - Window Functions: SUM() OVER(), AVG() OVER()
===============================================================================
*/

-- Calculate the total sales per month and the running total of sales over time 
SELECT 
	*,
	SUM(total_sales) OVER(PARTITION BY DATETRUNC(YEAR, order_date) ORDER BY order_date) AS rolling_total,
	AVG(avg_price) OVER(PARTITION BY DATETRUNC(YEAR, order_date) ORDER BY order_date) AS moving_average
FROM(SELECT
	DATETRUNC(MONTH, order_date) AS order_date,
	SUM(sale_amount) AS total_sales,
	AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
)t 

/*
===============================================================================
Performance Analysis (Year-over-Year, Month-over-Month)
===============================================================================
Purpose:
    - To measure the performance of products, customers, or regions over time.
    - For benchmarking and identifying high-performing entities.
    - To track yearly trends and growth.

SQL Functions Used:
    - LAG(): Accesses data from previous rows.
    - AVG() OVER(): Computes average values within partitions.
    - CASE: Defines conditional logic for trend analysis.
===============================================================================
*/

/* Analyze the yearly performance of products by comparing their sales 
to both the average sales performance of the product and the previous year's sales */

WITH yearly_product_sales AS(
SELECT
	YEAR(fs.order_date) AS order_year,
	dp.product_name	AS product_name,
	SUM(fs.sale_amount) AS current_sales
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products dp
ON fs.product_key = dp.product_key
WHERE order_date IS NOT NULL
GROUP BY YEAR(fs.order_date), dp.product_name
)

SELECT
	*,
	current_sales - avg_sales AS diff_avg,
	current_sales - previous_year_sales AS diff_sales,
	CASE	WHEN (current_sales - avg_sales) > 0 THEN 'Above Avg'
			WHEN (current_sales - avg_sales) < 0 THEN 'Below Avg'
			ELSE 'Avg'
	END AS avg_change,
	CASE	WHEN (current_sales - previous_year_sales) > 0 THEN 'Increasing'
			WHEN (current_sales - previous_year_sales) < 0 THEN 'Decreasing'
			WHEN (current_sales - previous_year_sales) IS NULL THEN NULL
			ELSE 'Same'
	END AS yoy_change
FROM(SELECT
		*,
		LAG(current_sales, 1)	OVER(PARTITION BY product_name ORDER BY order_year ASC) AS previous_year_sales,
		AVG(current_sales)		OVER(PARTITION BY product_name) AS avg_sales
	FROM yearly_product_sales
)t

/*
===============================================================================
Part-to-Whole Analysis
===============================================================================
Purpose:
    - To compare performance or metrics across dimensions or time periods.
    - To evaluate differences between categories.
    - Useful for A/B testing or regional comparisons.

SQL Functions Used:
    - SUM(), AVG(): Aggregates values for comparison.
    - Window Functions: SUM() OVER() for total calculations.
===============================================================================
*/
-- Which categories contribute the most to overall sales?
WITH category_sales AS(
	SELECT
		category,
		SUM(sale_amount) AS total_sale_category
	FROM gold.fact_sales AS fs
	LEFT JOIN gold.dim_products AS dp
	ON fs.product_key = dp.product_key
	GROUP BY category
)
SELECT
	*,
	SUM(total_sale_category) OVER() AS overall_sales,
	CONCAT(ROUND(total_sale_category/CAST(SUM(total_sale_category) OVER() AS FLOAT)*100, 2), '%') AS part2whole
FROM category_sales
ORDER BY part2whole DESC

/*
===============================================================================
Data Segmentation Analysis
===============================================================================
Purpose:
    - To group data into meaningful categories for targeted insights.
    - For customer segmentation, product categorization, or regional analysis.

SQL Functions Used:
    - CASE: Defines custom segmentation logic.
    - GROUP BY: Groups data into segments.
===============================================================================
*/

/*Segment products into cost ranges and 
count how many products fall into each segment*/
WITH product_segemnts AS(
SELECT
	product_name,
	cost,
	CASE	WHEN cost < 100 THEN 'Below 100'
			WHEN cost BETWEEN 100 AND 500 THEN '100-500'
			WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
			ELSE 'Above 1000'
	END AS cost_range
FROM gold.dim_products
)

SELECT 
	cost_range,
	COUNT(cost_range) AS nr_cost_range
FROM product_segemnts
GROUP BY cost_range
ORDER BY 2

WITH customer_segemnts AS(
SELECT
	customer_key,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
	SUM(sale_amount) AS total_sales
FROM gold.fact_sales
GROUP BY customer_key
)

SELECT
	customer_range,
	COUNT(customer_range) AS nr_customer_range
FROM(SELECT
	*,
	CASE	WHEN lifespan < 12 THEN 'New'	
			WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
			ELSE 'VIP'
	END AS customer_range
FROM customer_segemnts
)t GROUP BY customer_range