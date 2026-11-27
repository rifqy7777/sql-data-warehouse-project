SHOW INDEX FROM silver_customer_master;
SHOW INDEX FROM silver_sales_transaction;

-- Di master: PRIMARY KEY jika unik & tidak ada NULL; jika tidak pasti unik, pakai INDEX biasa dulu
ALTER TABLE silver_customer_master
ADD PRIMARY KEY (customer_id);

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
    -- demografi & segment
    c.customer_id,
    c.customer_name,
    c.customer_age,
    c.gender,
    c.customer_segment,
    COALESCE(NULLIF(TRIM(s.customer_type), ''), 'Prospect') AS customer_type,
    -- geografi
    c.region,
    c.customer_country,
    c.customer_state,
    c.customer_city,
    c.customer_postal_code,
    -- status & nilai crm
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


-- dim_crm_product_info
USE data_warehouse_ecommerce;

DROP TABLE IF EXISTS dim_erp_product_info;

CREATE TABLE dim_erp_product_info (
    product_key    INT UNSIGNED   NOT NULL AUTO_INCREMENT,
	product_id          VARCHAR(20),
    product_name        VARCHAR(120),
    product_category    VARCHAR(50),
    product_subcategory VARCHAR(50),
    brand               VARCHAR(50),
    supplier            VARCHAR(50),
    unit_price          DECIMAL(12, 2),
    product_cost        DECIMAL(12, 2),
    product_rating      DECIMAL(3, 1),
    data_load_dt        DATETIME DEFAULT CURRENT_TIMESTAMP
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
    data_load_dt
    CURRENT_TIMESTAMP AS data_load_dt
FROM silver_product_catalog;

-- dim_erp_channel_payment
-- 1. Buat tabel dimensi di Gold layer
CREATE TABLE dim_erp_channel_payment (
    channel_payment_key INT AUTO_INCREMENT PRIMARY KEY,
 	sales_channel  VARCHAR(30),
    payment_method VARCHAR(30),
    payment_status VARCHAR(20),
    currency	   VARCHAR(5),
    -- Composite index untuk mempercepat lookup ke fact_orders
    UNIQUE INDEX idx_channel_payment_combo (
        sales_channel, payment_method, payment_status, currency
    )
);

-- 2. Ekstrak 780 kombinasi unik dari Silver layer
INSERT INTO dim_erp_channel_payment (
    sales_channel, payment_method, payment_status, currency
)
SELECT DISTINCT
    sales_channel,
    payment_method,
    payment_status,
    currency
FROM silver_sales_transaction
ORDER BY sales_channel, payment_method, payment_status, currency;

--dim_erp_logisik
CREATE TABLE dim_erp_logistics (
    logistics_key INT AUTO_INCREMENT PRIMARY KEY,
    shipping_method           VARCHAR(20) NOT NULL,
    warehouse                 VARCHAR(15) NOT NULL,
    delivery_status           VARCHAR(20) NOT NULL,
    return_status             VARCHAR(20) NOT NULL,
    return_reason             VARCHAR(50) NOT NULL,
    
    -- Composite index untuk mempercepat lookup ke fact_orders
    UNIQUE INDEX idx_logistics_combo (
        shipping_method, warehouse, delivery_status, return_status, return_reason
    )
);

-- 2. Ekstrak 912 kombinasi unik dari Silver layer
INSERT INTO dim_erp_logistics (
    shipping_method, warehouse, delivery_status, return_status, return_reason
)
SELECT DISTINCT
    shipping_method,
    warehouse,
    delivery_status,
    COALESCE(return_status, 'Not Returned') AS return_status,
    COALESCE(return_reason, 'Not Applicable') AS return_reason
FROM silver_sales_transaction
ORDER BY warehouse, shipping_method, delivery_status, return_status, return_reason;

-- dim_crm_marketing_promo
-- 1. Buat tabel dimensi di Gold layer
CREATE TABLE dim_crm_marketing_promo (
    promo_key INT AUTO_INCREMENT PRIMARY KEY,
    marketing_channel VARCHAR(30) NOT NULL,
    campaign_name VARCHAR(50) NOT NULL,
    coupon_code VARCHAR(20) NOT NULL,
    has_coupon BOOLEAN NOT NULL,
    
    -- Composite index untuk mempercepat lookup ke fact_orders
    UNIQUE INDEX idx_promo_combo (
        marketing_channel, campaign_name, coupon_code
    )
);

-- 2. Ekstrak 1.230 kombinasi unik dari Silver layer
INSERT INTO dim_crm_marketing_promo (
    marketing_channel, campaign_name, coupon_code, has_coupon
)
SELECT DISTINCT
    marketing_channel,
    COALESCE(NULLIF(TRIM(campaign_name), ''), 'No Campaign') AS campaign_name,
    COALESCE(NULLIF(TRIM(coupon_code), ''), 'No Coupon') AS coupon_code,
    CASE 
        WHEN coupon_code IS NOT NULL AND TRIM(coupon_code) <> '' THEN TRUE 
        ELSE FALSE 
    END AS has_coupon
FROM silver_sales_transaction
ORDER BY marketing_channel, campaign_name, coupon_code;

