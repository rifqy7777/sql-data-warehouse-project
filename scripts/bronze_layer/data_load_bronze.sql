-- ============================================================================
-- BRONZE LAYER LOAD SCRIPT (PART B)
-- Keterangan : Memuat file CSV mentah ke tabel Bronze menggunakan pola
--              TRUNCATE + LOAD DATA INFILE agar dapat dijalankan ulang
--              dengan aman tanpa menggandakan data.
-- Kenapa tidak pakai Stored Procedure: MySQL melarang LOAD DATA INFILE di
--              dalam stored procedure; menjalankan skrip ini langsung juga
--              memudahkan pemantauan hasil load per file CSV.
-- ============================================================================

-- I. LOAD DATA: customer_master.csv -> bronze_customer_master
TRUNCATE TABLE bronze_customer_master;

LOAD DATA INFILE 'C:/data_warehouse_ecommerce/datasets/customer_master.csv'
INTO TABLE bronze_customer_master
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS (
    @customer_id,
    @customer_name,
    @customer_age,
    @gender,
    @customer_segment,
    @customer_city,
    @customer_state,
    @customer_country,
    @region,
    @customer_postal_code,
    @customer_acquisition_cost
)
SET
    customer_id               = NULLIF(@customer_id, ''),
    customer_name             = NULLIF(@customer_name, ''),
    customer_age              = NULLIF(@customer_age, ''),
    gender                    = NULLIF(@gender, ''),
    customer_segment          = NULLIF(@customer_segment, ''),
    customer_city             = NULLIF(@customer_city, ''),
    customer_state            = NULLIF(@customer_state, ''),
    customer_country          = NULLIF(@customer_country, ''),
    region                    = NULLIF(@region, ''),
    customer_postal_code      = NULLIF(@customer_postal_code, ''),
    customer_acquisition_cost = NULLIF(@customer_acquisition_cost, '');

-- II. LOAD DATA: product_catalog.csv -> bronze_product_catalog
TRUNCATE TABLE bronze_product_catalog;

LOAD DATA INFILE 'C:/data_warehouse_ecommerce/datasets/product_catalog.csv'
INTO TABLE bronze_product_catalog
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS (
    @product_id,
    @product_name,
    @product_category,
    @product_subcategory,
    @brand,
    @supplier,
    @unit_price,
    @product_cost,
    @product_rating
)
SET
    product_id          = NULLIF(@product_id, ''),
    product_name        = NULLIF(@product_name, ''),
    product_category    = NULLIF(@product_category, ''),
    product_subcategory = NULLIF(@product_subcategory, ''),
    brand               = NULLIF(@brand, ''),
    supplier            = NULLIF(@supplier, ''),
    unit_price          = NULLIF(@unit_price, ''),
    product_cost        = NULLIF(@product_cost, ''),
    product_rating      = NULLIF(@product_rating, '');

-- III. LOAD DATA: sales_transaction.csv -> bronze_sales_transaction
TRUNCATE TABLE bronze_sales_transaction;

LOAD DATA INFILE 'C:/data_warehouse_ecommerce/datasets/sales_transaction.csv'
INTO TABLE bronze_sales_transaction
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS (
    @order_id,
    @order_date,
    @order_time,
    @order_status,
    @sales_channel,
    @customer_id,
    @customer_name,
    @customer_age,
    @gender,
    @customer_segment,
    @customer_type,
    @customer_city,
    @customer_state,
    @customer_country,
    @region,
    @customer_postal_code,
    @payment_method,
    @payment_status,
    @currency,
    @shipping_method,
    @warehouse,
    @delivery_days,
    @estimated_delivery_days,
    @delivery_status,
    @return_status,
    @return_reason,
    @customer_rating,
    @review_sentiment,
    @customer_review,
    @marketing_channel,
    @campaign_name,
    @coupon_code,
    @loyalty_points_earned,
    @loyalty_points_redeemed,
    @quantity,
    @gross_sales,
    @discount_amount,
    @tax_amount,
    @shipping_cost,
    @net_sales,
    @product_cost,
    @profit,
    @profit_margin_percentage,
    @customer_lifetime_value,
    @is_repeat_customer,
    @customer_order_count
)
SET
    order_id                  = NULLIF(@order_id, ''),
    order_date                = NULLIF(@order_date, ''),
    order_time                = NULLIF(@order_time, ''),
    order_status              = NULLIF(@order_status, ''),
    sales_channel             = NULLIF(@sales_channel, ''),
    customer_id               = NULLIF(@customer_id, ''),
    customer_name             = NULLIF(@customer_name, ''),
    customer_age              = NULLIF(@customer_age, ''),
    gender                    = NULLIF(@gender, ''),
    customer_segment          = NULLIF(@customer_segment, ''),
    customer_type             = NULLIF(@customer_type, ''),
    customer_city             = NULLIF(@customer_city, ''),
    customer_state            = NULLIF(@customer_state, ''),
    customer_country          = NULLIF(@customer_country, ''),
    region                    = NULLIF(@region, ''),
    customer_postal_code      = NULLIF(@customer_postal_code, ''),
    payment_method            = NULLIF(@payment_method, ''),
    payment_status            = NULLIF(@payment_status, ''),
    currency                  = NULLIF(@currency, ''),
    shipping_method           = NULLIF(@shipping_method, ''),
    warehouse                 = NULLIF(@warehouse, ''),
    delivery_days             = NULLIF(@delivery_days, ''),
    estimated_delivery_days   = NULLIF(@estimated_delivery_days, ''),
    delivery_status           = NULLIF(@delivery_status, ''),
    return_status             = NULLIF(@return_status, ''),
    return_reason             = NULLIF(@return_reason, ''),
    customer_rating           = NULLIF(@customer_rating, ''),
    review_sentiment          = NULLIF(@review_sentiment, ''),
    customer_review           = NULLIF(@customer_review, ''),
    marketing_channel         = NULLIF(@marketing_channel, ''),
    campaign_name             = NULLIF(@campaign_name, ''),
    coupon_code               = NULLIF(@coupon_code, ''),
    loyalty_points_earned     = NULLIF(@loyalty_points_earned, ''),
    loyalty_points_redeemed   = NULLIF(@loyalty_points_redeemed, ''),
    quantity                  = NULLIF(@quantity, ''),
    gross_sales               = NULLIF(@gross_sales, ''),
    discount_amount           = NULLIF(@discount_amount, ''),
    tax_amount                = NULLIF(@tax_amount, ''),
    shipping_cost             = NULLIF(@shipping_cost, ''),
    net_sales                 = NULLIF(@net_sales, ''),
    product_cost              = NULLIF(@product_cost, ''),
    profit                    = NULLIF(@profit, ''),
    profit_margin_percentage  = NULLIF(@profit_margin_percentage, ''),
    customer_lifetime_value   = NULLIF(@customer_lifetime_value, ''),
    is_repeat_customer        = CASE
                                    WHEN LOWER(TRIM(@is_repeat_customer)) IN ('1', 'true', 'yes') THEN 1
                                    WHEN LOWER(TRIM(@is_repeat_customer)) IN ('0', 'false', 'no') THEN 0
                                    ELSE NULL
                                  END,
    customer_order_count      = NULLIF(@customer_order_count, '');

-- IV. LOAD DATA: order_items.csv -> bronze_order_items
TRUNCATE TABLE bronze_order_items;

LOAD DATA INFILE 'C:/data_warehouse_ecommerce/datasets/order_items.csv'
INTO TABLE bronze_order_items
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS (
    @order_id,
    @product_id,
    @quantity,
    @unit_price,
    @discount_percentage,
    @discount_amount,
    @gross_sales,
    @tax_amount,
    @shipping_cost,
    @net_sales,
    @product_cost,
    @profit
)
SET
    order_id            = NULLIF(@order_id, ''),
    product_id          = NULLIF(@product_id, ''),
    quantity            = NULLIF(@quantity, ''),
    unit_price          = NULLIF(@unit_price, ''),
    discount_percentage = NULLIF(@discount_percentage, ''),
    discount_amount     = NULLIF(@discount_amount, ''),
    gross_sales         = NULLIF(@gross_sales, ''),
    tax_amount          = NULLIF(@tax_amount, ''),
    shipping_cost       = NULLIF(@shipping_cost, ''),
    net_sales           = NULLIF(@net_sales, ''),
    product_cost        = NULLIF(@product_cost, ''),
    profit              = NULLIF(@profit, '');

-- VERIFIKASI JUMLAH BARIS: BRONZE LAYER
SELECT 'bronze_product_catalog'   AS nama_tabel, COUNT(*) AS total_baris FROM bronze_product_catalog
UNION ALL
SELECT 'bronze_customer_master'   AS nama_tabel, COUNT(*) AS total_baris FROM bronze_customer_master
UNION ALL
SELECT 'bronze_sales_transaction' AS nama_tabel, COUNT(*) AS total_baris FROM bronze_sales_transaction
UNION ALL
SELECT 'bronze_order_items'       AS nama_tabel, COUNT(*) AS total_baris FROM bronze_order_items;
