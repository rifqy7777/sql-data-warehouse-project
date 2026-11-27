-- Jalankan sekali saja jika kolom-kolom di bawah belum di-index di Silver layer
ALTER TABLE silver_sales_transaction
    ADD INDEX idx_sst_order_id (order_id),
    ADD INDEX idx_sst_customer_id (customer_id);

ALTER TABLE silver_order_items
    ADD INDEX idx_soi_order_id (order_id),
    ADD INDEX idx_soi_product_id (product_id);

USE data_warehouse_ecommerce;

-- ============================================================================
-- 1. FACT_ORDERS (Granularitas: 1 baris per order_id -> 138.116 baris)
-- ============================================================================
DROP TABLE IF EXISTS fact_orders;

CREATE TABLE fact_orders (
    order_id                 VARCHAR(20)    NOT NULL,
    customer_key             INT UNSIGNED   NOT NULL,
    date_key                 INT UNSIGNED   NOT NULL,
    time_key                 INT UNSIGNED   NOT NULL,
    logistics_key            INT UNSIGNED   NOT NULL,
    channel_payment_key      INT UNSIGNED   NOT NULL,
    promo_key                INT UNSIGNED   NOT NULL,
    order_status             VARCHAR(20)    NOT NULL,

    -- Metrik Finansial Header
    quantity                 INT UNSIGNED   NOT NULL,
    gross_sales              DECIMAL(12, 2) NOT NULL,
    discount_amount          DECIMAL(12, 2) NOT NULL,
    tax_amount               DECIMAL(12, 2) NOT NULL,
    shipping_cost            DECIMAL(10, 2) NOT NULL,
    net_sales                DECIMAL(12, 2) NOT NULL,
    product_cost             DECIMAL(12, 2) NOT NULL,
    profit                   DECIMAL(12, 2) NOT NULL,
    profit_margin_percentage DECIMAL(6, 2)  NOT NULL,

    -- Metrik SLA Logistik, Loyalitas & Ulasan
    delivery_days            DECIMAL(5, 1)  NULL,
    estimated_delivery_days  DECIMAL(5, 1)  NULL,
    loyalty_points_earned    INT UNSIGNED   NOT NULL DEFAULT 0,
    loyalty_points_redeemed  INT UNSIGNED   NOT NULL DEFAULT 0,
    customer_rating          DECIMAL(3, 1)  NULL,
    review_sentiment         VARCHAR(20)    NULL,
    customer_review          VARCHAR(150)   NULL,
    data_load_dt             DATETIME       DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (order_id),
    INDEX idx_fo_customer (customer_key),
    INDEX idx_fo_date (date_key),
    INDEX idx_fo_time (time_key),
    INDEX idx_fo_logistics (logistics_key),
    INDEX idx_fo_channel_payment (channel_payment_key),
    INDEX idx_fo_promo (promo_key)
);

TRUNCATE TABLE fact_orders;

INSERT INTO fact_orders (
    order_id,
    customer_key,
    date_key,
    time_key,
    logistics_key,
    channel_payment_key,
    promo_key,
    order_status,
    quantity,
    gross_sales,
    discount_amount,
    tax_amount,
    shipping_cost,
    net_sales,
    product_cost,
    profit,
    profit_margin_percentage,
    delivery_days,
    estimated_delivery_days,
    loyalty_points_earned,
    loyalty_points_redeemed,
    customer_rating,
    review_sentiment,
    customer_review,
    data_load_dt
)
SELECT
    st.order_id,
    dc.customer_key,
    CAST(DATE_FORMAT(STR_TO_DATE(st.order_date, '%Y-%m-%d'), '%Y%m%d') AS UNSIGNED) AS date_key,
    CAST(TIME_FORMAT(STR_TO_DATE(st.order_time, '%H:%i:%s'), '%H%i%s') AS UNSIGNED) AS time_key,
    dl.logistics_key,
    dcp.channel_payment_key,
    dmp.promo_key,
    st.order_status,
    st.quantity,
    st.gross_sales,
    st.discount_amount,
    st.tax_amount,
    st.shipping_cost,
    st.net_sales,
    st.product_cost,
    st.profit,
    st.profit_margin_percentage,
    NULLIF(CAST(st.delivery_days AS CHAR), '')           AS delivery_days,
    NULLIF(CAST(st.estimated_delivery_days AS CHAR), '') AS estimated_delivery_days,
    COALESCE(st.loyalty_points_earned, 0)                AS loyalty_points_earned,
    COALESCE(st.loyalty_points_redeemed, 0)              AS loyalty_points_redeemed,
    NULLIF(CAST(st.customer_rating AS CHAR), '')         AS customer_rating,
    NULLIF(TRIM(st.review_sentiment), '')                AS review_sentiment,
    NULLIF(TRIM(st.customer_review), '')                 AS customer_review,
    CURRENT_TIMESTAMP                                    AS data_load_dt
FROM silver_sales_transaction st
JOIN dim_crm_customer_info dc
    ON st.customer_id = dc.customer_id
JOIN dim_erp_logistics dl
    ON st.shipping_method = dl.shipping_method
   AND st.warehouse = dl.warehouse
   AND st.delivery_status = dl.delivery_status
   AND COALESCE(NULLIF(TRIM(st.return_status), ''), 'Not Returned') = dl.return_status
   AND COALESCE(NULLIF(TRIM(st.return_reason), ''), 'Not Applicable') = dl.return_reason
JOIN dim_erp_channel_payment dcp
    ON st.sales_channel = dcp.sales_channel
   AND st.payment_method = dcp.payment_method
   AND st.payment_status = dcp.payment_status
   AND st.currency = dcp.currency
JOIN dim_crm_marketing_promo dmp
    ON st.marketing_channel = dmp.marketing_channel
   AND COALESCE(NULLIF(TRIM(st.campaign_name), ''), 'No Campaign') = dmp.campaign_name
   AND COALESCE(NULLIF(TRIM(st.coupon_code), ''), 'No Coupon') = dmp.coupon_code;


-- ============================================================================
-- 2. FACT_ORDER_ITEMS (Granularitas: 1 baris per order_id + product_id -> 397.482 baris)
-- ============================================================================
DROP TABLE IF EXISTS fact_order_items;

CREATE TABLE fact_order_items (
    order_item_key      INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    order_id            VARCHAR(20)    NOT NULL,
    product_key         INT UNSIGNED   NOT NULL,
    customer_key        INT UNSIGNED   NOT NULL,
    date_key            INT UNSIGNED   NOT NULL,
    promo_key           INT UNSIGNED   NOT NULL,

    -- Metrik Rinci per Line-Item Produk
    quantity            INT UNSIGNED   NOT NULL,
    unit_price          DECIMAL(12, 2) NOT NULL,
    discount_percentage DECIMAL(6, 4)  NOT NULL,
    discount_amount     DECIMAL(12, 2) NOT NULL,
    gross_sales         DECIMAL(12, 2) NOT NULL,
    tax_amount          DECIMAL(12, 2) NOT NULL,
    shipping_cost       DECIMAL(10, 2) NOT NULL,
    net_sales           DECIMAL(12, 2) NOT NULL,
    product_cost        DECIMAL(12, 2) NOT NULL,
    profit              DECIMAL(12, 2) NOT NULL,
    data_load_dt        DATETIME       DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (order_item_key),
    UNIQUE KEY uq_order_product (order_id, product_key),
    INDEX idx_foi_order (order_id),
    INDEX idx_foi_product (product_key),
    INDEX idx_foi_customer (customer_key),
    INDEX idx_foi_date (date_key),
    INDEX idx_foi_promo (promo_key)
);

TRUNCATE TABLE fact_order_items;

INSERT INTO fact_order_items (
    order_id,
    product_key,
    customer_key,
    date_key,
    promo_key,
    quantity,
    unit_price,
    discount_percentage,
    discount_amount,
    gross_sales,
    tax_amount,
    shipping_cost,
    net_sales,
    product_cost,
    profit,
    data_load_dt
)
WITH clean_items AS (
    SELECT
        order_id,
        product_id,
        quantity,
        unit_price,
        discount_percentage,
        discount_amount,
        gross_sales,
        tax_amount,
        shipping_cost,
        net_sales,
        product_cost,
        profit,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, product_id
            ORDER BY gross_sales DESC
        ) AS rn
    FROM silver_order_items
)
SELECT
    ci.order_id,
    dp.product_key,
    fo.customer_key,
    fo.date_key,
    fo.promo_key,
    ci.quantity,
    ci.unit_price,
    ci.discount_percentage,
    ci.discount_amount,
    ci.gross_sales,
    ci.tax_amount,
    ci.shipping_cost,
    ci.net_sales,
    ci.product_cost,
    ci.profit,
    CURRENT_TIMESTAMP AS data_load_dt
FROM clean_items ci
JOIN dim_erp_product_info dp
    ON ci.product_id = dp.product_id
JOIN fact_orders fo
    ON ci.order_id = fo.order_id
WHERE ci.rn = 1;
