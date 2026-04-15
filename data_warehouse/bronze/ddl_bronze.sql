/*
=============================================================
Create Table
=============================================================
Script Purpose:
    This script creates 6 tables after checking if it already exists. 
    If the table exists, it is dropped and recreated. 
	
WARNING:
    Running this script will drop all the tables in the database if it exists. 
    All data in the table will be permanently deleted. 
    Proceed with caution and ensure you have proper backups before running this script.
*/


-- Drop and recreate the 'bronze.crm_cust_info' table
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.crm_cust_info;
END

CREATE TABLE bronze.crm_cust_info (
	cst_id				INT,
	cst_key				VARCHAR(50),
	cst_firstname		NVARCHAR(50),
	cst_lastname		NVARCHAR(50),
	cst_marital_status	NVARCHAR(50),
	cst_gndr			NVARCHAR(50),
	cst_create_date		DATE
);


-- Drop and recreate the 'bronze.crm_prd_info' table
IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.crm_prd_info;
END

CREATE TABLE bronze.crm_prd_info (
    prd_id			INT,
    prd_key			NVARCHAR(50),
    prd_nm			NVARCHAR(50),
    prd_cost		INT,
    prd_line		NVARCHAR(50),
    prd_start_dt	DATETIME,
    prd_end_dt		DATETIME
);


-- Drop and recreate the 'bronze.crm_sales_details' table
IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.crm_sales_details;
END

CREATE TABLE bronze.crm_sales_details (
    sls_ord_num		NVARCHAR(50),
    sls_prd_key		NVARCHAR(50),
    sls_cust_id		INT,
    sls_order_dt	INT,
    sls_ship_dt		INT,
    sls_due_dt		INT,
    sls_sales		INT,
    sls_quantity	INT,
    sls_price		INT
);


-- Drop and recreate the 'bronze.erp_CUST_AZ12' table
IF OBJECT_ID('bronze.erp_CUST_AZ12', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.erp_CUST_AZ12;
END

CREATE TABLE bronze.erp_CUST_AZ12 (
    CID		NVARCHAR(50),
    BDATE	DATE,
    GEN		NVARCHAR(50)
);


-- Drop and recreate the 'bronze.erp_LOC_A101' table
IF OBJECT_ID('bronze.erp_LOC_A101', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.erp_LOC_A101;
END

CREATE TABLE bronze.erp_LOC_A101 (
    CID		NVARCHAR(50),
    CNTRY	NVARCHAR(50)
);


-- Drop and recreate the 'bronze.erp_PX_CAT_G1V2' table
IF OBJECT_ID('bronze.erp_PX_CAT_G1V2', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.erp_PX_CAT_G1V2;
END

CREATE TABLE bronze.erp_PX_CAT_G1V2 (
    ID			NVARCHAR(50),
    CAT			NVARCHAR(50),
    SUBCAT		NVARCHAR(50),
    MAINTENANCE	NVARCHAR(50)
);