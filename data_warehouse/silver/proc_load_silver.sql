/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL process to populate the 'silver' schema 
	tables from 'bronze' schema. 
    It performs the following actions:
    - Truncates the silver tables before loading data.
    - Inserts transformed and cleaned data from Bronze to Silver layer.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.load_bronze;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME, @start_time DATETIME, @end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();

		PRINT '=============================================================';
		PRINT 'Loading Silver Layer'										 ;
		PRINT '=============================================================';

		PRINT '=============================================================';
		PRINT 'Loading CRM Tables'											 ;
		PRINT '=============================================================';
		
		SET @start_time = GETDATE();
		
		PRINT '>> Truncating Table: silver.crm_cust_info'
		TRUNCATE TABLE silver.crm_cust_info;
	
		PRINT '>> Inserting Data Into: silver.crm_cust_info'
		INSERT INTO silver.crm_cust_info (
			cst_id				,
			cst_key				,
			cst_firstname		,
			cst_lastname		,
			cst_marital_status	,
			cst_gndr			,
			cst_create_date)

		SELECT 
			cst_id				,
			cst_key				,
			TRIM(cst_firstname)	AS cst_firstname,
			TRIM(cst_lastname)	AS cst_lastname,
			CASE WHEN UPPER(cst_marital_status) = 'S' THEN 'Single'
				 WHEN UPPER(cst_marital_status) = 'M' THEN 'Married'
				 ELSE 'NA'
			END	AS	cst_marital_status,	-- Normalize marital status values to readable format
			CASE WHEN UPPER(cst_gndr) = 'F' THEN 'Female'
				 WHEN UPPER(cst_gndr) = 'M' THEN 'Male'
				 ELSE 'NA'
			END	AS	cst_gndr,	-- Normalize gender values to readable format
			cst_create_date
		FROM(
			SELECT 
				*,
				ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		)t WHERE flag_last = 1	-- Select the most recent record per customer

		SET @end_time = GETDATE();
		PRINT CONCAT('>> Load Duration: ', DATEDIFF(SECOND, @start_time, @end_time), ' seconds');
		PRINT '-------------------------------------------------------------';

		SET @start_time = GETDATE();
		
		PRINT '>> Truncating Table: silver.crm_prd_info'
		TRUNCATE TABLE silver.crm_prd_info;
	
		PRINT '>> Inserting Data Into: silver.crm_prd_info'
		INSERT INTO silver.crm_prd_info(
			prd_id			,
			cat_id			,
			prd_key			,
			prd_nm			,
			prd_cost		,
			prd_line		,
			prd_start_dt	,
			prd_end_dt
		)
		SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')	AS cat_id,	-- Extract category ID
			SUBSTRING(prd_key, 7, LEN(prd_key))	AS	prd_key,		-- Extract Product Key
			prd_nm,
			ISNULL(prd_cost, 0)	AS	prd_cost,
			CASE	UPPER(TRIM(prd_line))
					WHEN 'R' THEN 'Road'
					WHEN 'M' THEN 'Mountain'
					WHEN 'S' THEN 'Other Sales'
					WHEN 'T' THEN 'Touring'
					ELSE 'NA'	-- Normalize Product Line values to readable format
			END AS prd_line,
			CAST(prd_start_dt AS DATE) AS prd_start_dt,
			CAST(
				DATEADD(DAY, -1, LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt ASC)) 
				AS DATE
				) AS prd_end_dt	-- Calculate end date as one day before the next start date
		FROM bronze.crm_prd_info 

		SET @end_time = GETDATE();
		PRINT CONCAT('>> Load Duration: ', DATEDIFF(SECOND, @start_time, @end_time), ' seconds');
		PRINT '-------------------------------------------------------------';

		SET @start_time = GETDATE();
		
		PRINT '>> Truncating Table: silver.crm_sales_details'
		TRUNCATE TABLE silver.crm_sales_details;
		
		PRINT '>> Inserting Data Into: silver.crm_sales_details'
		INSERT INTO silver.crm_sales_details(
			sls_ord_num		,
			sls_prd_key		,
			sls_cust_id		,
			sls_order_dt	,
			sls_ship_dt		,
			sls_due_dt		,
			sls_sales		,
			sls_quantity	,
			sls_price
		)
		SELECT 
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE	WHEN sls_order_dt =	0 OR LEN(sls_order_dt)	!= 8 THEN NULL
					ELSE CAST(CAST(sls_order_dt	AS VARCHAR(8)) AS DATE)
			END AS sls_order_dt,
			CASE	WHEN sls_ship_dt =	0 OR LEN(sls_ship_dt)	!= 8 THEN NULL
					ELSE CAST(CAST(sls_ship_dt	AS VARCHAR(8)) AS DATE) 
			END AS sls_ship_dt,
			CASE	WHEN sls_due_dt =	0 OR LEN(sls_due_dt)	!= 8 THEN NULL
					ELSE CAST(CAST(sls_due_dt	AS VARCHAR(8)) AS DATE) 
			END AS sls_due_dt,
			CASE	WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
						THEN sls_quantity * ABS(sls_price)
					ELSE sls_sales
			END AS sls_sales,	-- Recalculate sales if original  value is missing or incorrect
			sls_quantity,
			CASE	WHEN sls_price IS NULL OR sls_price <= 0
						THEN sls_sales / NULLIF(sls_quantity,0)
					ELSE sls_price	-- Derive price if original value is invalid
			END AS	sls_price
		FROM bronze.crm_sales_details

		SET @end_time = GETDATE();
		PRINT CONCAT('>> Load Duration: ', DATEDIFF(SECOND, @start_time, @end_time), ' seconds');
		PRINT '-------------------------------------------------------------';
		
		PRINT '=============================================================';
		PRINT 'Loading ERP Tables'											 ;
		PRINT '=============================================================';

		SET @start_time = GETDATE();
		
		PRINT '>> Truncating Table: silver.erp_cust_az12'
		TRUNCATE TABLE silver.erp_cust_az12;
		
		PRINT '>> Inserting Data Into: silver.erp_cust_az12'

		INSERT INTO silver.erp_cust_az12(
			CID		,
			BDATE	,
			GEN
		)

		SELECT 
			CASE	WHEN CID LIKE 'NAS%' THEN SUBSTRING(CID, 4, LEN(CID)) -- Remove 'NAS' prefix if present
					ELSE CID
			END	AS CID,
			CASE	WHEN BDATE > GETDATE() THEN NULL
					ELSE BDATE
			END	AS BDATE,	-- Set future birthdates to NULLL
			CASE	WHEN UPPER(TRIM(GEN)) IN ('M', 'Male')		THEN 'Male'
					WHEN UPPER(TRIM(GEN)) IN ('F', 'Female')	THEN 'Female'
					ELSE 'NA'
			END AS GEN		-- Normalize Gender values to readable format and handle unknown cases
		FROM bronze.erp_cust_az12

		SET @end_time = GETDATE();
		PRINT CONCAT('>> Load Duration: ', DATEDIFF(SECOND, @start_time, @end_time), ' seconds');
		PRINT '-------------------------------------------------------------';

		SET @start_time = GETDATE();
		
		PRINT '>> Truncating Table: silver.erp_LOC_A101'
		TRUNCATE TABLE silver.erp_LOC_A101;
		
		PRINT '>> Inserting Data Into: silver.erp_LOC_A101'

		INSERT INTO silver.erp_LOC_A101(
			CID		,
			CNTRY	
		)

		SELECT 
			REPLACE(CID, '-', '')	AS CID,
			CASE	WHEN TRIM(CNTRY) = 'DE'	THEN 'Germany'
					WHEN TRIM(CNTRY) IN ('USA', 'US')	THEN 'United States'
					WHEN TRIM(CNTRY) = '' OR CNTRY IS NULL	THEN 'NA'
					ELSE CNTRY
			END AS CNTRY	-- Normalize and Handle missing or blank country codes
		FROM bronze.erp_LOC_A101

		SET @end_time = GETDATE();
		PRINT CONCAT('>> Load Duration: ', DATEDIFF(SECOND, @start_time, @end_time), ' seconds');
		PRINT '-------------------------------------------------------------';

		SET @start_time = GETDATE();
		
		PRINT '>> Truncating Table: silver.erp_PX_CAT_G1V2'
		TRUNCATE TABLE silver.erp_PX_CAT_G1V2;
		
		PRINT '>> Inserting Data Into: silver.erp_PX_CAT_G1V2'

		INSERT INTO silver.erp_PX_CAT_G1V2(
			ID		   ,
			CAT		   ,
			SUBCAT	   ,
			MAINTENANCE
		)

		SELECT
			ID		   ,
			CAT		   ,
			SUBCAT	   ,
			MAINTENANCE
		FROM bronze.erp_PX_CAT_G1V2

		SET @end_time = GETDATE();
		PRINT CONCAT('>> Load Duration: ', DATEDIFF(SECOND, @start_time, @end_time), ' seconds');
		PRINT '-------------------------------------------------------------';

		SET @batch_end_time = GETDATE();
		PRINT '=============================================================';
		PRINT 'Loading Silver Layer Completed'										 ;
		PRINT CONCAT('>> Batch Load Duration: ', DATEDIFF(SECOND, @batch_start_time, @batch_end_time), ' seconds');
		PRINT '=============================================================';
	END TRY
	BEGIN CATCH
		PRINT '=============================================================';
		PRINT ('An Error Occured during loading Silver Layer');
		PRINT CONCAT('Error Message: '	, ERROR_MESSAGE());
		PRINT CONCAT('Error Number: '	, ERROR_NUMBER());
		PRINT CONCAT('Error Line: '		, ERROR_LINE());
		PRINT CONCAT('Error Message'	, ERROR_STATE());
		PRINT CONCAT('Error Procedure: ', ERROR_PROCEDURE());
		PRINT '=============================================================';
	END CATCH
END;