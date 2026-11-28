USE data_warehouse_ecommerce;

-- ============================================================================
-- GOLD LAYER PRE-LOAD AUDIT & RECONCILIATION CHECKS (DIMENSIONS & FACTS)
-- Purpose : Verify coverage, uniqueness, date/time parsing safety, lookup
--           completeness before INNER JOINs, and deduplication impacts before
--           loading Gold dimension and fact tables from Silver.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. DIM_CRM_CUSTOMER_INFO CHECKS
--    - Master vs transaction coverage (prospects without orders)
--    - Whether a single customer_id has multiple/changing CRM/retention values
--      across transactions (justifying latest order_date/order_id snapshot)

-- ----------------------------------------------------------------------------

-- ============================================================================
-- 1a. Cek total customer di master, yang punya transaksi, dan yang belum transaksi (Prospect)
-- Purpose     : Audit customer coverage between silver_customer_master and
--               silver_sales_transaction to identify customers with no transaction
--               history and verify fallback handling for missing CRM attributes.
-- Status      : Out of 25,000 master customers, 24,911 have transaction records
--               while 89 customers have no transactions and are classified as
--               'Prospect' with default zero values for CLV, repeat flag, and order count.
-- ============================================================================
SELECT
    COUNT(*) AS total_silver_customers,
    SUM(CASE WHEN tx.customer_id IS NOT NULL THEN 1 ELSE 0 END) AS customers_with_tx,
    SUM(CASE WHEN tx.customer_id IS NULL THEN 1 ELSE 0 END) AS customers_without_tx_prospect,
    SUM(CASE WHEN tx.customer_type IS NULL OR TRIM(tx.customer_type) = '' THEN 1 ELSE 0 END) AS null_or_blank_tx_customer_type
FROM silver_customer_master c
LEFT JOIN (
    SELECT
        customer_id,
        customer_type,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date DESC, order_id DESC
        ) AS rn
    FROM silver_sales_transaction
    WHERE customer_id IS NOT NULL
      AND TRIM(customer_id) <> ''
) tx
    ON c.customer_id = tx.customer_id
   AND tx.rn = 1;

-- ============================================================================
-- 1b. Cek apakah 1 customer_id memiliki >1 nilai berbeda untuk atribut CRM/retensi di transaksi
-- Purpose     : Audit intra-customer consistency across repeat transactions in
--               silver_sales_transaction to verify whether CRM and retention
--               attributes (customer_type, customer_lifetime_value,
--               is_repeat_customer, customer_order_count) vary across orders
--               before applying latest-order snapshot deduplication (rn = 1).
-- Status      : Out of 24,911 customers in transactions (24,387 with multiple
--               orders), 0 customers showed conflicting values across orders,
--               confirming latest-order snapshot selection (rn = 1) preserves full
--               attribute accuracy without data loss.
-- ============================================================================

WITH per_cust_distinct AS (
    SELECT
        customer_id,
        COUNT(*) AS tx_rows,
        COUNT(DISTINCT COALESCE(NULLIF(TRIM(customer_type), ''), '__NULL__')) AS distinct_cust_type,
        COUNT(DISTINCT COALESCE(customer_lifetime_value, -999999.99)) AS distinct_clv,
        COUNT(DISTINCT COALESCE(is_repeat_customer, -1)) AS distinct_repeat_flag,
        COUNT(DISTINCT COALESCE(customer_order_count, -1)) AS distinct_order_count
    FROM silver_sales_transaction
    WHERE customer_id IS NOT NULL
      AND TRIM(customer_id) <> ''
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS total_customers_in_tx,
    SUM(CASE WHEN tx_rows > 1 THEN 1 ELSE 0 END) AS multi_tx_customers,
    SUM(CASE WHEN distinct_cust_type > 1 THEN 1 ELSE 0 END) AS changing_customer_type,
    SUM(CASE WHEN distinct_clv > 1 THEN 1 ELSE 0 END) AS changing_clv,
    SUM(CASE WHEN distinct_repeat_flag > 1 THEN 1 ELSE 0 END) AS changing_repeat_flag,
    SUM(CASE WHEN distinct_order_count > 1 THEN 1 ELSE 0 END) AS changing_order_count
FROM per_cust_distinct;

-- ============================================================================
-- 2. DIM_ERP_PRODUCT_INFO CHECKS
--    - Row count & product_id uniqueness in silver_product_catalog
--    - Check if any product_id in silver_order_items is missing from catalog
-- Purpose     : Audit product_id uniqueness, completeness, and formatting in
--               silver_product_catalog to ensure a clean 1:1 grain mapping
--               for dim_erp_product_info.
-- Status      : Verified all 1,175 catalog rows contain unique, valid product_id
--               values (1,175 distinct IDs; 0 NULL or blank values), confirming
--               safe 1:1 loading into dim_erp_product_info.
-- ============================================================================

SELECT
    COUNT(*) AS total_catalog_rows,
    COUNT(DISTINCT product_id) AS distinct_product_ids,
    SUM(CASE WHEN product_id IS NULL OR TRIM(product_id) = '' THEN 1 ELSE 0 END) AS invalid_product_ids
FROM silver_product_catalog;

SELECT
    COUNT(DISTINCT oi.product_id) AS missing_product_ids_in_catalog,
    COUNT(*) AS affected_order_item_rows
FROM silver_order_items oi
LEFT JOIN silver_product_catalog pc
    ON oi.product_id = pc.product_id
WHERE pc.product_id IS NULL;

-- ============================================================================
-- ----------------------------------------------------------------------------
-- 3. DIM_ERP_CHANNEL_PAYMENT CHECKS
--    - Distinct combinations & NULL/empty checks on channel, payment, currency
-- Purpose     : Audit completeness and cardinality of sales_channel, payment_method,
--               payment_status, and currency in silver_sales_transaction to ensure
--               all attributes satisfy NOT NULL constraints and maintain low
--               dimensional cardinality before building dim_erp_channel_payment.
-- Status      : Verified across all 138,116 transactions; 0 NULL or blank values
--               found across all four attributes, producing 780 distinct
--               combinations for dim_erp_channel_payment.
-- ----------------------------------------------------------------------------
-- ============================================================================

SELECT
    COUNT(*) AS total_tx_rows,
    SUM(CASE WHEN sales_channel IS NULL OR TRIM(sales_channel) = '' THEN 1 ELSE 0 END) AS null_or_blank_sales_channel,
    SUM(CASE WHEN payment_method IS NULL OR TRIM(payment_method) = '' THEN 1 ELSE 0 END) AS null_or_blank_payment_method,
    SUM(CASE WHEN payment_status IS NULL OR TRIM(payment_status) = '' THEN 1 ELSE 0 END) AS null_or_blank_payment_status,
    SUM(CASE WHEN currency IS NULL OR TRIM(currency) = '' THEN 1 ELSE 0 END) AS null_or_blank_currency
FROM silver_sales_transaction;

SELECT COUNT(*) AS distinct_channel_payment_combos
FROM (
    SELECT DISTINCT
        sales_channel,
        payment_method,
        payment_status,
        currency
    FROM silver_sales_transaction
) t;

-- ============================================================================
-- ----------------------------------------------------------------------------
-- 4. DIM_ERP_LOGISTICS CHECKS
--    - Distinct combinations & NULL/blank vs populated patterns on return fields
-- Purpose     : Audit completeness of core logistics attributes
--               (shipping_method, warehouse, delivery_status) and quantify
--               NULL/blank return fields in silver_sales_transaction to verify
--               safe NOT NULL loading and standardized fallback mapping
--               ('Not Returned' / 'Not Applicable') for dim_erp_logistics.
-- Status      : Verified across 138,116 transactions; 0 NULL or blank values in
--               shipping_method, warehouse, and delivery_status, while 128,654
--               rows on both return_status and return_reason were mapped to
--               'Not Returned' and 'Not Applicable' across 912 logistics combinations.
-- ----------------------------------------------------------------------------
-- ============================================================================

SELECT
    COUNT(*) AS total_tx_rows,
    SUM(CASE WHEN shipping_method IS NULL OR TRIM(shipping_method) = '' THEN 1 ELSE 0 END) AS null_or_blank_shipping_method,
    SUM(CASE WHEN warehouse IS NULL OR TRIM(warehouse) = '' THEN 1 ELSE 0 END) AS null_or_blank_warehouse,
    SUM(CASE WHEN delivery_status IS NULL OR TRIM(delivery_status) = '' THEN 1 ELSE 0 END) AS null_or_blank_delivery_status,
    SUM(CASE WHEN return_status IS NULL OR TRIM(return_status) = '' THEN 1 ELSE 0 END) AS mapped_to_not_returned,
    SUM(CASE WHEN return_reason IS NULL OR TRIM(return_reason) = '' THEN 1 ELSE 0 END) AS mapped_to_not_applicable
FROM silver_sales_transaction;

SELECT COUNT(*) AS distinct_logistics_combos
FROM (
    SELECT DISTINCT
        shipping_method,
        warehouse,
        delivery_status,
        COALESCE(NULLIF(TRIM(return_status), ''), 'Not Returned') AS return_status,
        COALESCE(NULLIF(TRIM(return_reason), ''), 'Not Applicable') AS return_reason
    FROM silver_sales_transaction
) t;

-- ============================================================================
-- ----------------------------------------------------------------------------
-- 5. DIM_CRM_MARKETING_PROMO CHECKS
--    - Distinct combinations, coupon presence vs blank/NULL, has_coupon split
-- Purpose     : Audit completeness of marketing_channel, quantify NULL/blank
--               campaign_name and coupon_code rows, and verify distinct promo
--               combinations before loading dim_crm_marketing_promo.
-- Status      : Verified across 138,116 transactions; 0 NULL or blank values
--               in marketing_channel, 83,233 rows mapped to 'No Campaign', and
--               coupon usage split into 27,614 with-coupon vs 110,502 without-coupon
--               rows ('No Coupon', has_coupon = 0) across 1,230 combinations.
-- ----------------------------------------------------------------------------
-- ============================================================================

SELECT
    COUNT(*) AS total_tx_rows,
    SUM(CASE WHEN marketing_channel IS NULL OR TRIM(marketing_channel) = '' THEN 1 ELSE 0 END) AS null_or_blank_marketing_channel,
    SUM(CASE WHEN campaign_name IS NULL OR TRIM(campaign_name) = '' THEN 1 ELSE 0 END) AS mapped_to_no_campaign,
    SUM(CASE WHEN coupon_code IS NOT NULL AND TRIM(coupon_code) <> '' THEN 1 ELSE 0 END) AS with_coupon_rows,
    SUM(CASE WHEN coupon_code IS NULL OR TRIM(coupon_code) = '' THEN 1 ELSE 0 END) AS without_coupon_rows
FROM silver_sales_transaction;

SELECT COUNT(*) AS distinct_promo_combos
FROM (
    SELECT DISTINCT
        marketing_channel,
        COALESCE(NULLIF(TRIM(campaign_name), ''), 'No Campaign') AS campaign_name,
        COALESCE(NULLIF(TRIM(coupon_code), ''), 'No Coupon') AS coupon_code
    FROM silver_sales_transaction
) t;


-- ----------------------------------------------------------------------------
-- 6. DIM_DATE & DIM_TIME CHECKS
--    - NULL/invalid parsing safety for STR_TO_DATE on order_date & order_time
--    - Min/max bounds & distinct key counts
-- Purpose     : Audit completeness, STR_TO_DATE parsing safety, temporal bounds,
--               and distinct key cardinality for order_date and order_time in
--               silver_sales_transaction before loading dim_date and dim_time.
-- Status      : Verified across all 138,116 transactions; 0 NULL or failed parses
--               for both fields, spanning 2021-01-01 to 2025-12-31 (1,826
--               distinct dates) and 00:00:00 to 23:59:59 (68,991 distinct times).
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*) AS total_tx_rows,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN STR_TO_DATE(order_date, '%Y-%m-%d') IS NULL THEN 1 ELSE 0 END) AS failed_date_parse,
    MIN(STR_TO_DATE(order_date, '%Y-%m-%d')) AS min_order_date,
    MAX(STR_TO_DATE(order_date, '%Y-%m-%d')) AS max_order_date,
    COUNT(DISTINCT STR_TO_DATE(order_date, '%Y-%m-%d')) AS distinct_dates,
    SUM(CASE WHEN order_time IS NULL THEN 1 ELSE 0 END) AS null_order_time,
    SUM(CASE WHEN STR_TO_DATE(order_time, '%H:%i:%s') IS NULL THEN 1 ELSE 0 END) AS failed_time_parse,
    MIN(STR_TO_DATE(order_time, '%H:%i:%s')) AS min_order_time,
    MAX(STR_TO_DATE(order_time, '%H:%i:%s')) AS max_order_time,
    COUNT(DISTINCT STR_TO_DATE(order_time, '%H:%i:%s')) AS distinct_times
FROM silver_sales_transaction;


-- ----------------------------------------------------------------------------
-- 7. FACT_ORDERS PRE-JOIN COMPLETENESS CHECK (AVOIDING UNEXPECTED ROW LOSS)
--    - Verify every silver_sales_transaction row matches all dimension lookups
--      before executing INNER JOINs in fact_orders load
-- Purpose     : Perform a LEFT JOIN dry-run lookup from silver_sales_transaction
--               across dim_crm_customer_info, dim_erp_logistics,
--               dim_erp_channel_payment, and dim_crm_marketing_promo to detect
--               unmatched foreign keys and prevent silent row loss prior to
--               loading fact_orders via INNER JOIN.
-- Status      : Verified across 138,116 silver order rows; 0 unmatched keys found
--               across all four dimensions (0 rows dropped), confirming safe
--               INNER JOIN execution for fact_orders.
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*) AS total_silver_orders,
    SUM(CASE WHEN dc.customer_id IS NULL THEN 1 ELSE 0 END) AS unmatched_customer,
    SUM(CASE WHEN dl.logistics_key IS NULL THEN 1 ELSE 0 END) AS unmatched_logistics,
    SUM(CASE WHEN dcp.channel_payment_key IS NULL THEN 1 ELSE 0 END) AS unmatched_channel_payment,
    SUM(CASE WHEN dmp.promo_key IS NULL THEN 1 ELSE 0 END) AS unmatched_promo,
    SUM(
        CASE
            WHEN dc.customer_id IS NULL
              OR dl.logistics_key IS NULL
              OR dcp.channel_payment_key IS NULL
              OR dmp.promo_key IS NULL
            THEN 1 ELSE 0
        END
    ) AS total_rows_dropped_by_inner_join
FROM silver_sales_transaction st
LEFT JOIN dim_crm_customer_info dc
    ON st.customer_id = dc.customer_id
LEFT JOIN dim_erp_logistics dl
    ON st.shipping_method = dl.shipping_method
   AND st.warehouse = dl.warehouse
   AND st.delivery_status = dl.delivery_status
   AND COALESCE(NULLIF(TRIM(st.return_status), ''), 'Not Returned') = dl.return_status
   AND COALESCE(NULLIF(TRIM(st.return_reason), ''), 'Not Applicable') = dl.return_reason
LEFT JOIN dim_erp_channel_payment dcp
    ON st.sales_channel = dcp.sales_channel
   AND st.payment_method = dcp.payment_method
   AND st.payment_status = dcp.payment_status
   AND st.currency = dcp.currency
LEFT JOIN dim_crm_marketing_promo dmp
    ON st.marketing_channel = dmp.marketing_channel
   AND COALESCE(NULLIF(TRIM(st.campaign_name), ''), 'No Campaign') = dmp.campaign_name
   AND COALESCE(NULLIF(TRIM(st.coupon_code), ''), 'No Coupon') = dmp.coupon_code;


-- ----------------------------------------------------------------------------
-- 8. FACT_ORDER_ITEMS DEDUPLICATION & JOIN IMPACT CHECKS
--    - Inspect duplicate (order_id, product_id) pairs in silver_order_items
--    - Quantify row reduction (e.g., 397,569 -> 397,482) and financial delta
--      when keeping only ROW_NUMBER() ... ORDER BY gross_sales DESC rn = 1
--    - Check unmatched product_id or order_id before fact_order_items load
-- ----------------------------------------------------------------------------
WITH ranked_items AS (
    SELECT
        order_id,
        product_id,
        quantity,
        gross_sales,
        net_sales,
        profit,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, product_id
            ORDER BY gross_sales DESC
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY order_id, product_id
        ) AS pair_cnt
    FROM silver_order_items
)
SELECT
    COUNT(*) AS total_silver_order_items,
    COUNT(DISTINCT CONCAT(order_id, '||', product_id)) AS unique_order_product_pairs,
    SUM(CASE WHEN pair_cnt > 1 THEN 1 ELSE 0 END) AS rows_in_multi_line_pairs,
    SUM(CASE WHEN rn > 1 THEN 1 ELSE 0 END) AS rows_dropped_by_dedup,
    ROUND(SUM(gross_sales), 2) AS raw_gross_sales,
    ROUND(SUM(CASE WHEN rn = 1 THEN gross_sales ELSE 0 END), 2) AS dedup_gross_sales,
    ROUND(SUM(CASE WHEN rn > 1 THEN gross_sales ELSE 0 END), 2) AS dropped_gross_sales,
    ROUND(SUM(profit), 2) AS raw_profit,
    ROUND(SUM(CASE WHEN rn = 1 THEN profit ELSE 0 END), 2) AS dedup_profit,
    ROUND(SUM(CASE WHEN rn > 1 THEN profit ELSE 0 END), 2) AS dropped_profit
FROM ranked_items;

SELECT
    COUNT(*) AS total_oi_rows,
    SUM(CASE WHEN dp.product_id IS NULL THEN 1 ELSE 0 END) AS unmatched_product_in_dim,
    SUM(CASE WHEN fo.order_id IS NULL THEN 1 ELSE 0 END) AS unmatched_order_in_fact_orders
FROM silver_order_items oi
LEFT JOIN dim_erp_product_info dp
    ON oi.product_id = dp.product_id
LEFT JOIN fact_orders fo
    ON oi.order_id = fo.order_id;
