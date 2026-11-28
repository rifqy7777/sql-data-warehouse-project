USE data_warehouse_ecommerce;

-- Drop child table first to avoid foreign key constraint conflicts during rebuilds.
DROP TABLE IF EXISTS silver_order_items;

-- ============================================================================
-- Table     : silver_customer_master
-- Objective : Define the Silver layer customer master table with a unique
--             customer identifier and load timestamp metadata.
-- Changes   : Added data_load_dt column with default CURRENT_TIMESTAMP and
--             set PRIMARY KEY on customer_id.
-- ============================================================================
DROP TABLE IF EXISTS silver_customer_master;

CREATE TABLE silver_customer_master (
    customer_id               VARCHAR(20) NOT NULL,
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
    data_load_dt              DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id)
);

-- ============================================================================
-- Table     : silver_product_catalog
-- Objective : Define the Silver layer product catalog table with standardized
--             pricing, cost, and rating types plus load timestamp metadata.
-- Changes   : Added data_load_dt column with default CURRENT_TIMESTAMP and
--             set PRIMARY KEY on product_id.
-- ============================================================================
DROP TABLE IF EXISTS silver_product_catalog;

CREATE TABLE silver_product_catalog (
    product_id          VARCHAR(20) NOT NULL,
    product_name        VARCHAR(120),
    product_category    VARCHAR(50),
    product_subcategory VARCHAR(50),
    brand               VARCHAR(50),
    supplier            VARCHAR(50),
    unit_price          DECIMAL(12, 2),
    product_cost        DECIMAL(12, 2),
    product_rating      DECIMAL(3, 1),
    data_load_dt        DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id)
);

-- ============================================================================
-- Table     : silver_sales_transaction
-- Objective : Define the Silver layer sales transaction table with order,
--             customer, shipping, financial measures, and profit DQ columns.
-- Changes   : Fixed PRIMARY KEY to order_id (matching existing columns and
--             supporting order_id foreign key references), aligned FK name to
--             silver_customer_master, and added dq_profit_status,
--             dq_loss_driver, and data_load_dt columns.
-- ============================================================================
DROP TABLE IF EXISTS silver_sales_transaction;

CREATE TABLE silver_sales_transaction (
    -- 1. Order & Waktu
    order_id                  VARCHAR(20) NOT NULL,
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
    delivery_days             DECIMAL(5, 1) NULL,
    estimated_delivery_days   DECIMAL(5, 1) NULL,
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
    gross_sales               DECIMAL(14, 2),
    discount_amount           DECIMAL(14, 2),
    tax_amount                DECIMAL(14, 2),
    shipping_cost             DECIMAL(14, 2),
    net_sales                 DECIMAL(14, 2),
    product_cost              DECIMAL(14, 2),
    profit                    DECIMAL(14, 2),
    profit_margin_percentage  DECIMAL(6, 2),
    customer_lifetime_value   DECIMAL(14, 2),
    is_repeat_customer        TINYINT(1),
    customer_order_count      INT,

    -- 6. Data Quality & Metadata
    dq_profit_status          VARCHAR(20),
    dq_loss_driver            VARCHAR(60),
    data_load_dt              DATETIME DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (order_id),
    CONSTRAINT fk_st_customer_master
        FOREIGN KEY (customer_id) REFERENCES silver_customer_master (customer_id)
);

-- ============================================================================
-- Table     : silver_order_items
-- Objective : Define the Silver layer order line-item table with sequence
--             numbering, financial measures, and profit DQ columns.
-- Changes   : Kept composite PRIMARY KEY (order_id, product_id, line_item_seq),
--             renamed foreign key constraints to match referenced tables
--             (silver_sales_transaction and silver_product_catalog), and
--             added dq_profit_status, dq_loss_driver, and data_load_dt
--             columns.
-- ============================================================================
DROP TABLE IF EXISTS silver_order_items;
CREATE TABLE silver_order_items (
    order_id            VARCHAR(20) NOT NULL,
    product_id          VARCHAR(20) NOT NULL,
    line_item_seq       INT NOT NULL,
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
    dq_profit_status    VARCHAR(20),
    dq_loss_driver      VARCHAR(60),
    data_load_dt        DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id, product_id, line_item_seq),
    CONSTRAINT fk_oi_sales_transaction
        FOREIGN KEY (order_id) REFERENCES silver_sales_transaction (order_id),
    CONSTRAINT fk_oi_product_catalog
        FOREIGN KEY (product_id) REFERENCES silver_product_catalog (product_id)
);
