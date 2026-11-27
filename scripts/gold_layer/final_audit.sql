USE data_warehouse_ecommerce;

-- ============================================================================
-- FINAL AUDIT & SIGN-OFF GOLD LAYER STAR SCHEMA
-- ============================================================================
SHOW WARNINGS;

-- 1. ROW COUNT VS TARGET
SELECT
    table_name,
    actual_rows,
    target_rows,
    (actual_rows - target_rows) AS diff_rows,
    CASE
        WHEN actual_rows = target_rows THEN 'PASS'
        ELSE 'CHECK'
    END AS audit_status
FROM (
    SELECT 'dim_crm_customer_info'   AS table_name, COUNT(*) AS actual_rows, 25000  AS target_rows FROM dim_crm_customer_info
    UNION ALL
    SELECT 'dim_erp_product_info',                  COUNT(*),                1175   FROM dim_erp_product_info
    UNION ALL
    SELECT 'dim_erp_channel_payment',               COUNT(*),                780    FROM dim_erp_channel_payment
    UNION ALL
    SELECT 'dim_erp_logistics',                     COUNT(*),                912    FROM dim_erp_logistics
    UNION ALL
    SELECT 'dim_crm_marketing_promo',               COUNT(*),                1230   FROM dim_crm_marketing_promo
    UNION ALL
    SELECT 'dim_date',                              COUNT(*),                1826   FROM dim_date
    UNION ALL
    SELECT 'dim_time',                              COUNT(*),                68991  FROM dim_time
    UNION ALL
    SELECT 'fact_orders',                           COUNT(*),                138116 FROM fact_orders
    UNION ALL
    SELECT 'fact_order_items',                      COUNT(*),                397482 FROM fact_order_items
) t;

-- 2. GRAIN UNIQUENESS CHECK (Harusnya masing-masing mengembalikan 0 baris)
SELECT 'fact_orders_dup_order_id' AS check_name, order_id AS key_val, COUNT(*) AS dup_cnt
FROM fact_orders
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT 'fact_order_items_dup_order_product' AS check_name, CONCAT(order_id, '-', product_key) AS key_val, COUNT(*) AS dup_cnt
FROM fact_order_items
GROUP BY order_id, product_key
HAVING COUNT(*) > 1;

-- 3. FOREIGN KEY & METRIC SANITY CHECK
SELECT
    'fact_orders'                                                     AS fact_table,
    COUNT(*)                                                          AS total_rows,
    MIN(date_key)                                                     AS min_date_key,
    MAX(date_key)                                                     AS max_date_key,
    SUM(customer_key IS NULL OR customer_key = 0)                     AS bad_customer_key,
    SUM(date_key IS NULL OR date_key = 0)                             AS bad_date_key,
    SUM(time_key IS NULL OR time_key = 0)                             AS bad_time_key,
    SUM(logistics_key IS NULL OR logistics_key = 0)                   AS bad_logistics_key,
    SUM(channel_payment_key IS NULL OR channel_payment_key = 0)       AS bad_channel_payment_key,
    SUM(promo_key IS NULL OR promo_key = 0)                           AS bad_promo_key,
    SUM(quantity)                                                     AS total_qty,
    SUM(gross_sales)                                                  AS total_gross_sales,
    SUM(net_sales)                                                    AS total_net_sales,
    SUM(profit)                                                       AS total_profit
FROM fact_orders

UNION ALL

SELECT
    'fact_order_items'                                                AS fact_table,
    COUNT(*)                                                          AS total_rows,
    MIN(date_key)                                                     AS min_date_key,
    MAX(date_key)                                                     AS max_date_key,
    SUM(customer_key IS NULL OR customer_key = 0)                     AS bad_customer_key,
    SUM(date_key IS NULL OR date_key = 0)                             AS bad_date_key,
    0                                                                 AS bad_time_key,
    0                                                                 AS bad_logistics_key,
    0                                                                 AS bad_channel_payment_key,
    SUM(promo_key IS NULL OR promo_key = 0)                           AS bad_promo_key,
    SUM(quantity)                                                     AS total_qty,
    SUM(gross_sales)                                                  AS total_gross_sales,
    SUM(net_sales)                                                    AS total_net_sales,
    SUM(profit)                                                       AS total_profit
FROM fact_order_items;

ALTER TABLE fact_orders
    ADD CONSTRAINT fk_fo_customer FOREIGN KEY (customer_key)        REFERENCES dim_crm_customer_info(customer_key),
    ADD CONSTRAINT fk_fo_date     FOREIGN KEY (date_key)            REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_fo_time     FOREIGN KEY (time_key)            REFERENCES dim_time(time_key),
    ADD CONSTRAINT fk_fo_logistic FOREIGN KEY (logistics_key)       REFERENCES dim_erp_logistics(logistics_key),
    ADD CONSTRAINT fk_fo_channel  FOREIGN KEY (channel_payment_key) REFERENCES dim_erp_channel_payment(channel_payment_key),
    ADD CONSTRAINT fk_fo_promo    FOREIGN KEY (promo_key)           REFERENCES dim_crm_marketing_promo(promo_key);

ALTER TABLE fact_order_items
    ADD CONSTRAINT fk_foi_order    FOREIGN KEY (order_id)     REFERENCES fact_orders(order_id),
    ADD CONSTRAINT fk_foi_product  FOREIGN KEY (product_key)  REFERENCES dim_erp_product_info(product_key),
    ADD CONSTRAINT fk_foi_customer FOREIGN KEY (customer_key) REFERENCES dim_crm_customer_info(customer_key),
    ADD CONSTRAINT fk_foi_date     FOREIGN KEY (date_key)     REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_foi_promo    FOREIGN KEY (promo_key)    REFERENCES dim_crm_marketing_promo(promo_key);
