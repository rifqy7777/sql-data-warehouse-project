USE data_warehouse_ecommerce;

-- ============================================================================
-- 1. SILVER PRODUCT CATALOG (DDL)
-- ============================================================================
DROP TABLE IF EXISTS silver_product_catalog;

CREATE TABLE silver_product_catalog (
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
);

-- ============================================================================
-- 2. SILVER CUSTOMER MASTER (DDL)
-- ============================================================================
DROP TABLE IF EXISTS silver_customer_master;

CREATE TABLE silver_customer_master (
    customer_id               VARCHAR(20),
    customer_name             VARCHAR(100),
    customer_age              INT,
    gender                    VARCHAR(20),
    customer_segment          VARCHAR(20),
    customer_city             VARCHAR(50),
    customer_state            VARCHAR(50),
    customer_country          VARCHAR(30),
    region                    VARCHAR(20),
    customer_postal_code      VARCHAR(20),
    customer_acquisition_cost DECIMAL(12, 2),
    data_load_dt              DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 3. SILVER SALES TRANSACTION (DDL)
-- ============================================================================
DROP TABLE IF EXISTS silver_sales_transaction;

CREATE TABLE silver_sales_transaction (
    -- 1. Order & Waktu
    order_id                  VARCHAR(20),
    order_date                DATE,
    order_time                TIME,
    order_status              VARCHAR(20),
    sales_channel             VARCHAR(30),

    -- 2. Customer & Lokasi
    customer_id               VARCHAR(20),
    customer_name             VARCHAR(100),
    customer_age              INT,
    gender                    VARCHAR(20),
    customer_segment          VARCHAR(20),
    customer_type             VARCHAR(20),
    customer_city             VARCHAR(50),
    customer_state            VARCHAR(50),
    customer_country          VARCHAR(30),
    region                    VARCHAR(20),
    customer_postal_code      VARCHAR(20),

    -- 3. Pembayaran & Pengiriman
    payment_method            VARCHAR(30),
    payment_status            VARCHAR(20),
    currency                  VARCHAR(5),
    shipping_method           VARCHAR(20),
    warehouse                 VARCHAR(15),
    delivery_days             INT NULL,
    estimated_delivery_days   INT NULL,
    delivery_status           VARCHAR(20),

    -- 4. Retur, Review, Marketing & Loyalty
    return_status             VARCHAR(20) NULL,
    return_reason             VARCHAR(50) NULL,
    customer_rating           DECIMAL(3, 1) NULL,
    review_sentiment          VARCHAR(20) NULL,
    customer_review           VARCHAR(150) NULL,
    marketing_channel         VARCHAR(30),
    campaign_name             VARCHAR(50) NULL,
    coupon_code               VARCHAR(20) NULL,
    loyalty_points_earned     INT,
    loyalty_points_redeemed   INT,

    -- 5. Measures Keuangan & Retensi
    quantity                  INT,
    gross_sales               DECIMAL(12, 2),
    discount_amount           DECIMAL(12, 2),
    tax_amount                DECIMAL(12, 2),
    shipping_cost             DECIMAL(12, 2),
    net_sales                 DECIMAL(12, 2),
    product_cost              DECIMAL(12, 2),
    profit                    DECIMAL(12, 2),
    profit_margin_percentage  DECIMAL(6, 2),
    customer_lifetime_value   DECIMAL(12, 2),
    is_repeat_customer        TINYINT(1),
    customer_order_count      INT,

    -- 6. Metadata
    data_load_dt              DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 4. SILVER ORDER ITEMS (DDL)
-- ============================================================================
DROP TABLE IF EXISTS silver_order_items;

CREATE TABLE silver_order_items (
    order_id            VARCHAR(20),
    product_id          VARCHAR(20),
    quantity            INT,
    unit_price          DECIMAL(12, 2),
    discount_percentage DECIMAL(10, 6),
    discount_amount     DECIMAL(12, 2),
    gross_sales         DECIMAL(12, 2),
    tax_amount          DECIMAL(12, 2),
    shipping_cost       DECIMAL(12, 2),
    net_sales           DECIMAL(12, 2),
    product_cost        DECIMAL(12, 2),
    profit              DECIMAL(12, 2),
    data_load_dt        DATETIME DEFAULT CURRENT_TIMESTAMP
);
