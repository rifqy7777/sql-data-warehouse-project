SHOW INDEX FROM silver_customer_master;
SHOW INDEX FROM silver_sales_transaction;

-- Di master: PRIMARY KEY jika unik & tidak ada NULL; jika tidak pasti unik, pakai INDEX biasa dulu
ALTER TABLE silver_customer_master
ADD PRIMARY KEY (customer_id);

ALTER TABLE silver_product_catalog
ADD PRIMARY KEY (product_id);

-- Di sales: INDEX biasa (karena customer_id berulang di tiap transaksi)
ALTER TABLE silver_sales_transaction
ADD INDEX idx_sales_customer_id (customer_id);

-- demografi and segment check
--a customer name
SELECT
	c.customer_id,
	c.customer_name,
    COUNT(DISTINCT c.customer_id) AS total_customer_master,
    COUNT(DISTINCT CASE WHEN s.customer_id IS NULL THEN c.customer_id END) AS customer_belum_pernah_transaksi
FROM silver_customer_master c
LEFT JOIN silver_sales_transaction s
    ON c.customer_id = s.customer_id;

SELECT
    c.customer_id,
    c.customer_name
FROM silver_customer_master c
WHERE NOT EXISTS (
    SELECT 1
    FROM silver_sales_transaction s
    WHERE s.customer_id = c.customer_id
);

-- beda nama, umur, gender, segment,
SELECT
    COUNT(*) AS total_baris_join,
    SUM(COALESCE(s.customer_name, '') <> COALESCE(c.customer_name, '')) AS beda_nama,
    SUM(COALESCE(s.customer_age, -1) <> COALESCE(c.customer_age, -1)) AS beda_umur,
    SUM(COALESCE(s.gender, '') <> COALESCE(c.gender, '')) AS beda_gender,
    SUM(COALESCE(s.customer_segment, '') <> COALESCE(c.customer_segment, '')) AS beda_segment
FROM silver_sales_transaction s
INNER JOIN silver_customer_master c
    ON s.customer_id = c.customer_id;

-- BEDA DEMOGRAFI
SELECT
    SUM(COALESCE(s.customer_city, '') <> COALESCE(c.customer_city, '')) AS beda_city,
    SUM(COALESCE(s.customer_state, '') <> COALESCE(c.customer_state, '')) AS beda_state,
    SUM(COALESCE(s.customer_country, '') <> COALESCE(c.customer_country, '')) AS beda_country,
    SUM(COALESCE(s.region, '') <> COALESCE(c.region, '')) AS beda_region,
    SUM(COALESCE(s.customer_postal_code, '') <> COALESCE(c.customer_postal_code, '')) AS beda_postal_code
FROM silver_sales_transaction s
INNER JOIN silver_customer_master c
    ON s.customer_id = c.customer_id;

-- status/ nilai crm


USE data_warehouse_ecommerce;
USE data_warehouse_ecommerce;

-- ============================================================================
-- 1. DIM_CRM_CUSTOMER_INFO (25.000 baris)
-- ============================================================================
DROP TABLE IF EXISTS dim_crm_customer_info;

CREATE TABLE dim_crm_customer_info (
    customer_key              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id               VARCHAR(20)  NOT NULL,
    customer_name             VARCHAR(100),
    customer_age              INT,
    gender                    VARCHAR(20),
    customer_segment          VARCHAR(20),
    customer_type             VARCHAR(20)  NOT NULL DEFAULT 'Prospect',
    region                    VARCHAR(20),
    customer_country          VARCHAR(30),
    customer_state            VARCHAR(50),
    customer_city             VARCHAR(50),
    customer_postal_code      VARCHAR(20),
    customer_acquisition_cost DECIMAL(12, 2),
    customer_lifetime_value   DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    is_repeat_customer        TINYINT(1)   NOT NULL DEFAULT 0,
    customer_order_count      INT UNSIGNED NOT NULL DEFAULT 0,
    data_load_dt              DATETIME     DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_key),
    UNIQUE KEY uq_customer_id (customer_id)
);

TRUNCATE TABLE dim_crm_customer_info;

INSERT INTO dim_crm_customer_info (
    customer_id,
    customer_name,
    customer_age,
    gender,
    customer_segment,
    customer_type,
    region,
    customer_country,
    customer_state,
    customer_city,
    customer_postal_code,
    customer_acquisition_cost,
    customer_lifetime_value,
    is_repeat_customer,
    customer_order_count,
    data_load_dt
)
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_age,
    c.gender,
    c.customer_segment,
    COALESCE(NULLIF(TRIM(s.customer_type), ''), 'Prospect') AS customer_type,
    c.region,
    c.customer_country,
    c.customer_state,
    c.customer_city,
    c.customer_postal_code,
    c.customer_acquisition_cost,
    COALESCE(s.customer_lifetime_value, 0.00) AS customer_lifetime_value,
    COALESCE(s.is_repeat_customer, 0) AS is_repeat_customer,
    COALESCE(s.customer_order_count, 0) AS customer_order_count,
    CURRENT_TIMESTAMP AS data_load_dt
FROM silver_customer_master c
LEFT JOIN (
    SELECT
        customer_id,
        order_date,
        order_id,
        customer_type,
        customer_lifetime_value,
        is_repeat_customer,
        customer_order_count,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date DESC, order_id DESC
        ) AS rn
    FROM silver_sales_transaction
    WHERE customer_id IS NOT NULL
) AS s
    ON c.customer_id = s.customer_id
   AND s.rn = 1;


-- ============================================================================
-- 2. DIM_ERP_PRODUCT_INFO (1.175 baris)
-- ============================================================================
DROP TABLE IF EXISTS dim_erp_product_info;

CREATE TABLE dim_erp_product_info (
    product_key         INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    product_id          VARCHAR(20)    NOT NULL,
    product_name        VARCHAR(120),
    product_category    VARCHAR(50),
    product_subcategory VARCHAR(50),
    brand               VARCHAR(50),
    supplier            VARCHAR(50),
    unit_price          DECIMAL(12, 2),
    product_cost        DECIMAL(12, 2),
    product_rating      DECIMAL(3, 1),
    data_load_dt        DATETIME       DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_key),
    UNIQUE KEY uq_product_id (product_id)
);

TRUNCATE TABLE dim_erp_product_info;

INSERT INTO dim_erp_product_info (
    product_id,
    product_name,
    product_category,
    product_subcategory,
    brand,
    supplier,
    unit_price,
    product_cost,
    product_rating,
    data_load_dt
)
SELECT
    product_id,
    product_name,
    product_category,
    product_subcategory,
    brand,
    supplier,
    unit_price,
    product_cost,
    product_rating,
    CURRENT_TIMESTAMP AS data_load_dt
FROM silver_product_catalog;


-- ============================================================================
-- 3. DIM_ERP_CHANNEL_PAYMENT (780 baris)
-- ============================================================================
DROP TABLE IF EXISTS dim_erp_channel_payment;

CREATE TABLE dim_erp_channel_payment (
    channel_payment_key INT UNSIGNED NOT NULL AUTO_INCREMENT,
    sales_channel       VARCHAR(30)  NOT NULL,
    payment_method      VARCHAR(30)  NOT NULL,
    payment_status      VARCHAR(20)  NOT NULL,
    currency            VARCHAR(5)   NOT NULL,
    data_load_dt        DATETIME     DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (channel_payment_key),
    UNIQUE INDEX idx_channel_payment_combo (
        sales_channel, payment_method, payment_status, currency
    )
);

TRUNCATE TABLE dim_erp_channel_payment;

INSERT INTO dim_erp_channel_payment (
    sales_channel,
    payment_method,
    payment_status,
    currency,
    data_load_dt
)
SELECT DISTINCT
    sales_channel,
    payment_method,
    payment_status,
    currency,
    CURRENT_TIMESTAMP AS data_load_dt
FROM silver_sales_transaction
ORDER BY sales_channel, payment_method, payment_status, currency;


-- ============================================================================
-- 4. DIM_ERP_LOGISTICS (912 baris)
-- ============================================================================
DROP TABLE IF EXISTS dim_erp_logistics;

CREATE TABLE dim_erp_logistics (
    logistics_key   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    shipping_method VARCHAR(20)  NOT NULL,
    warehouse       VARCHAR(15)  NOT NULL,
    delivery_status VARCHAR(20)  NOT NULL,
    return_status   VARCHAR(20)  NOT NULL,
    return_reason   VARCHAR(50)  NOT NULL,
    data_load_dt    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (logistics_key),
    UNIQUE INDEX idx_logistics_combo (
        shipping_method, warehouse, delivery_status, return_status, return_reason
    )
);

TRUNCATE TABLE dim_erp_logistics;

INSERT INTO dim_erp_logistics (
    shipping_method,
    warehouse,
    delivery_status,
    return_status,
    return_reason,
    data_load_dt
)
SELECT DISTINCT
    shipping_method,
    warehouse,
    delivery_status,
    COALESCE(NULLIF(TRIM(return_status), ''), 'Not Returned') AS return_status,
    COALESCE(NULLIF(TRIM(return_reason), ''), 'Not Applicable') AS return_reason,
    CURRENT_TIMESTAMP AS data_load_dt
FROM silver_sales_transaction
ORDER BY warehouse, shipping_method, delivery_status, return_status, return_reason;


-- ============================================================================
-- 5. DIM_CRM_MARKETING_PROMO (1.230 baris)
-- ============================================================================
DROP TABLE IF EXISTS dim_crm_marketing_promo;

CREATE TABLE dim_crm_marketing_promo (
    promo_key         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    marketing_channel VARCHAR(30)  NOT NULL,
    campaign_name     VARCHAR(50)  NOT NULL,
    coupon_code       VARCHAR(20)  NOT NULL,
    has_coupon        TINYINT(1)   NOT NULL,
    data_load_dt      DATETIME     DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (promo_key),
    UNIQUE INDEX idx_promo_combo (
        marketing_channel, campaign_name, coupon_code
    )
);

TRUNCATE TABLE dim_crm_marketing_promo;

INSERT INTO dim_crm_marketing_promo (
    marketing_channel,
    campaign_name,
    coupon_code,
    has_coupon,
    data_load_dt
)
SELECT DISTINCT
    marketing_channel,
    COALESCE(NULLIF(TRIM(campaign_name), ''), 'No Campaign') AS campaign_name,
    COALESCE(NULLIF(TRIM(coupon_code), ''), 'No Coupon') AS coupon_code,
    CASE 
        WHEN coupon_code IS NOT NULL AND TRIM(coupon_code) <> '' THEN 1 
        ELSE 0 
    END AS has_coupon,
    CURRENT_TIMESTAMP AS data_load_dt
FROM silver_sales_transaction
ORDER BY marketing_channel, campaign_name, coupon_code;


-- ============================================================================
-- 6. DIM_DATE (1.826 baris)
-- ============================================================================
DROP TABLE IF EXISTS dim_date;

CREATE TABLE dim_date (
    date_key     INT UNSIGNED      NOT NULL,
    full_date    DATE              NOT NULL,
    day_of_month TINYINT UNSIGNED  NOT NULL,
    month_num    TINYINT UNSIGNED  NOT NULL,
    month_name   VARCHAR(15)       NOT NULL,
    quarter_num  TINYINT UNSIGNED  NOT NULL,
    year_num     SMALLINT UNSIGNED NOT NULL,
    day_name     VARCHAR(15)       NOT NULL,
    is_weekend   TINYINT(1)        NOT NULL,
    data_load_dt DATETIME          DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (date_key),
    UNIQUE KEY uq_full_date (full_date)
);

TRUNCATE TABLE dim_date;

INSERT INTO dim_date (
    date_key,
    full_date,
    day_of_month,
    month_num,
    month_name,
    quarter_num,
    year_num,
    day_name,
    is_weekend,
    data_load_dt
)
SELECT DISTINCT
    CAST(DATE_FORMAT(STR_TO_DATE(order_date, '%Y-%m-%d'), '%Y%m%d') AS UNSIGNED) AS date_key,
    STR_TO_DATE(order_date, '%Y-%m-%d') AS full_date,
    DAY(STR_TO_DATE(order_date, '%Y-%m-%d')) AS day_of_month,
    MONTH(STR_TO_DATE(order_date, '%Y-%m-%d')) AS month_num,
    MONTHNAME(STR_TO_DATE(order_date, '%Y-%m-%d')) AS month_name,
    QUARTER(STR_TO_DATE(order_date, '%Y-%m-%d')) AS quarter_num,
    YEAR(STR_TO_DATE(order_date, '%Y-%m-%d')) AS year_num,
    DAYNAME(STR_TO_DATE(order_date, '%Y-%m-%d')) AS day_name,
    CASE WHEN DAYOFWEEK(STR_TO_DATE(order_date, '%Y-%m-%d')) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend,
    CURRENT_TIMESTAMP AS data_load_dt
FROM silver_sales_transaction
ORDER BY date_key;


-- ============================================================================
-- 7. DIM_TIME (68.991 baris)
-- ============================================================================
DROP TABLE IF EXISTS dim_time;

CREATE TABLE dim_time (
    time_key     INT UNSIGNED     NOT NULL,
    full_time    TIME             NOT NULL,
    hour_num     TINYINT UNSIGNED NOT NULL,
    minute_num   TINYINT UNSIGNED NOT NULL,
    time_bucket  VARCHAR(20)      NOT NULL,
    data_load_dt DATETIME         DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (time_key),
    UNIQUE KEY uq_full_time (full_time)
);

TRUNCATE TABLE dim_time;

INSERT INTO dim_time (
    time_key,
    full_time,
    hour_num,
    minute_num,
    time_bucket,
    data_load_dt
)
SELECT DISTINCT
    CAST(TIME_FORMAT(STR_TO_DATE(order_time, '%H:%i:%s'), '%H%i%s') AS UNSIGNED) AS time_key,
    STR_TO_DATE(order_time, '%H:%i:%s') AS full_time,
    HOUR(STR_TO_DATE(order_time, '%H:%i:%s')) AS hour_num,
    MINUTE(STR_TO_DATE(order_time, '%H:%i:%s')) AS minute_num,
    CASE 
        WHEN HOUR(STR_TO_DATE(order_time, '%H:%i:%s')) BETWEEN 6 AND 11 THEN 'Morning (06-11)'
        WHEN HOUR(STR_TO_DATE(order_time, '%H:%i:%s')) BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
        WHEN HOUR(STR_TO_DATE(order_time, '%H:%i:%s')) BETWEEN 18 AND 23 THEN 'Evening (18-23)'
        ELSE 'Night (00-05)'
    END AS time_bucket,
    CURRENT_TIMESTAMP AS data_load_dt
FROM silver_sales_transaction
ORDER BY time_key;


---
SELECT 'dim_crm_customer_info'   AS table_name, COUNT(*) AS total_rows FROM dim_crm_customer_info
UNION ALL
SELECT 'dim_erp_product_info',                  COUNT(*) FROM dim_erp_product_info
UNION ALL
SELECT 'dim_erp_channel_payment',               COUNT(*) FROM dim_erp_channel_payment
UNION ALL
SELECT 'dim_erp_logistics',                     COUNT(*) FROM dim_erp_logistics
UNION ALL
SELECT 'dim_crm_marketing_promo',               COUNT(*) FROM dim_crm_marketing_promo
UNION ALL
SELECT 'dim_date',                              COUNT(*) FROM dim_date
UNION ALL
SELECT 'dim_time',                              COUNT(*) FROM dim_time;

