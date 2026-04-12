-- =============================================================================
-- Create View Table: gold.report_customers
-- =============================================================================
IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

CREATE VIEW gold.report_customers AS
/*------------------------------------------------------------------------------
 1) Base query: Retrives core columns from tables
------------------------------------------------------------------------------*/
WITH base_query AS(
SELECT
	dc.customer_key,
	dc.customer_number,
	fs.product_key,
	fs.order_number,
	CONCAT(COALESCE(first_name,''), ' ', COALESCE(last_name,'')) AS customer_name,
	DATEDIFF(YEAR, birthdate, GETDATE()) AS age,
	fs.sale_amount,
	fs.quantity,
	fs.order_date
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers dc
ON fs.customer_key = dc.customer_key
WHERE fs.order_date IS NOT NULL)

/*------------------------------------------------------------------------------
2) Customer Aggregations: Summarize key metrics at the customer level
------------------------------------------------------------------------------*/
, customer_agg AS(

SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number)	AS total_orders,
	SUM(sale_amount)	AS total_sales,
	SUM(quantity)		AS total_quantity,
	COUNT(DISTINCT product_key)	AS total_products,
	MAX(order_date) AS last_order_date,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
GROUP BY customer_key, customer_number, customer_name, age
)
/*------------------------------------------------------------------------------
3) Final Query: Combines all customers results into one output
------------------------------------------------------------------------------*/
SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE	WHEN lifespan < 12 THEN 'New'	
			WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
			ELSE 'VIP'
	END AS customer_segment,
	CASE	WHEN age < 20 THEN 'Under 20'
			WHEN age BETWEEN 20 AND 29 THEN '20-29'
			WHEN age BETWEEN 30 AND 39 THEN '30-39'
			WHEN age BETWEEN 40 AND 49 THEN '40-49'
			ELSE '50 and above'
	END AS age_group,
	last_order_date,
	DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
	total_orders,
	total_sales,
	total_quantity,
	total_products,
	lifespan,
	CASE	WHEN total_sales = 0 THEN 0
			ELSE total_sales/total_orders 
	END AS avg_order_value,
	CASE	WHEN lifespan = 0 THEN total_sales
			ELSE total_sales/lifespan 
	END AS avg_monthly_spend
FROM customer_agg;

GO