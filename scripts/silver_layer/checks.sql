-- ============================================================================
-- TABLE 1: BRONZE_CUSTOMER_MASTER (DATA QUALITY CHECK)
-- Description : Initial data quality audit on the customer master table.
-- Purpose     : Check primary key uniqueness, NULL/empty values, leading/trailing
--               spaces, and numeric plausibility before loading into the Silver layer.
-- Scope       :
--   1. Uniqueness and cleanliness of the primary key (customer_id).
--   2. Cleanliness and potential duplication of customer names (customer_name).
--   3. Value variations, NULLs, empty strings, extra spaces, and postal code
--      distribution across categorical and location columns.
--   4. Min/max ranges and anomalies in age and CAC.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- I. CHECK PRIMARY KEY (customer_id)
-- Description : Inspect customer_id values that are NULL, empty, padded with
--               spaces, or appear in more than one row.
-- Purpose     : Ensure every customer record is uniquely identifiable.
-- Scope       : Rows where customer_id is NULL, empty string, has leading/trailing
--               spaces, or total_rows is greater than 1.
-- ----------------------------------------------------------------------------

SELECT
    customer_id,
    CASE
        WHEN customer_id IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_id) = '' THEN 'Empty String'
        WHEN customer_id <> TRIM(customer_id) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_check,
    COUNT(*) AS total_rows
FROM bronze_customer_master
GROUP BY customer_id
HAVING customer_id IS NULL
    OR COUNT(*) > 1
    OR TRIM(customer_id) = ''
    OR customer_id <> TRIM(customer_id);

-- ----------------------------------------------------------------------------
-- II. CHECK CUSTOMER NAME (customer_name)
-- Description : Inspect text conditions and potential duplicates in customer_name.
-- Purpose     : Detect blank or padded customer names, or repeated/mismatched
--               values within the query scope.
-- Scope       : customer_id, customer_name, and status_cek for empty strings,
--               leading/trailing spaces, and duplicate occurrences.
-- ----------------------------------------------------------------------------
SELECT
    customer_id,
    customer_name,
    CASE
        WHEN customer_name IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_name) = '' THEN 'Empty String'
        WHEN customer_name <> TRIM(customer_name) THEN 'Has Leading/Trailing Space'
        WHEN COUNT(DISTINCT customer_name) > 1 THEN 'Duplicated'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_customer_master
HAVING COUNT(DISTINCT customer_id) > 1
    OR TRIM(customer_name) = ''
    OR customer_name <> TRIM(customer_name);

-- ----------------------------------------------------------------------------
-- III. CHECK CATEGORICAL & LOCATION COLUMNS
--      (gender, segment, city, state, country, region, postal_code)
-- Description : Review distinct values and text cleanliness across customer
--               demographic and address attributes.
-- Purpose     : Identify category variations, NULL/empty values, extra spaces,
--               and postal codes shared across multiple customers.
-- Scope       : Distinct values and status_cek for gender, customer_segment,
--               customer_city, customer_state, customer_country, and region,
--               plus distinct customer counts per customer_postal_code.
-- ----------------------------------------------------------------------------

-- a. Gender: check category variations, NULLs, and leading/trailing spaces
SELECT DISTINCT
    gender,
    CASE
        WHEN gender IS NULL THEN 'NULL Value'
        WHEN TRIM(gender) = '' THEN 'Empty String'
        WHEN gender <> TRIM(gender) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_customer_master
ORDER BY gender;

-- b. Customer Segment: check segment variations, NULLs, and leading/trailing spaces
SELECT DISTINCT
    customer_segment,
    CASE
        WHEN customer_segment IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_segment) = '' THEN 'Empty String'
        WHEN customer_segment <> TRIM(customer_segment) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_customer_master
ORDER BY customer_segment;

-- c. Customer City: check city names, NULLs, and leading/trailing spaces
SELECT DISTINCT
    customer_city,
    CASE
        WHEN customer_city IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_city) = '' THEN 'Empty String'
        WHEN customer_city <> TRIM(customer_city) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_customer_master
ORDER BY customer_city;

-- d. Customer State: check state/province names, NULLs, and leading/trailing spaces
SELECT DISTINCT
    customer_state,
    CASE
        WHEN customer_state IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_state) = '' THEN 'Empty String'
        WHEN customer_state <> TRIM(customer_state) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_customer_master
ORDER BY customer_state;

-- e. Customer Country: check country names, NULLs, and leading/trailing spaces
SELECT DISTINCT
    customer_country,
    CASE
        WHEN customer_country IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_country) = '' THEN 'Empty String'
        WHEN customer_country <> TRIM(customer_country) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_customer_master
ORDER BY customer_country;

-- f. Region: check region values, NULLs, and leading/trailing spaces
SELECT DISTINCT
    region,
    CASE
        WHEN region IS NULL THEN 'NULL Value'
        WHEN TRIM(region) = '' THEN 'Empty String'
        WHEN region <> TRIM(region) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_customer_master
ORDER BY region;

-- g. Postal_Code: check NULLs, duplicates, and leading/trailing spaces
SELECT
    customer_postal_code,
    COUNT(DISTINCT customer_id) AS total_customer,
    CASE
        WHEN customer_postal_code IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_postal_code) = '' THEN 'Empty String'
        WHEN customer_postal_code <> TRIM(customer_postal_code) THEN 'Has Leading/Trailing Space'
        WHEN COUNT(DISTINCT customer_id) > 1 THEN 'Duplicated'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_customer_master
GROUP BY customer_postal_code
HAVING COUNT(DISTINCT customer_id) > 1
ORDER BY total_customer DESC, customer_postal_code;

-- ----------------------------------------------------------------------------
-- IV. CHECK NUMERIC COLUMNS (customer_age & customer_acquisition_cost)
-- Description : Basic summary statistics and anomaly counts for numeric fields.
-- Purpose     : Verify that customer age and acquisition cost fall within
--               reasonable bounds with minimal NULL or negative values.
-- Scope       : Min/max values and anomaly counts for customer_age (NULL,
--               less than 15, or greater than 100) and customer_acquisition_cost
--               (NULL or less than 0).
-- ----------------------------------------------------------------------------
SELECT
    MIN(customer_age) AS min_age,
    MAX(customer_age) AS max_age,
    SUM(CASE WHEN customer_age IS NULL OR customer_age < 15 OR customer_age > 100 THEN 1 ELSE 0 END) AS age_anomalies,
    MIN(customer_acquisition_cost) AS min_cac,
    MAX(customer_acquisition_cost) AS max_cac,
    SUM(CASE WHEN customer_acquisition_cost IS NULL OR customer_acquisition_cost < 0 THEN 1 ELSE 0 END) AS cac_anomalies
FROM bronze_customer_master;

-- ============================================================================
-- TABLE 2: BRONZE_PRODUCT_CATALOG (DATA QUALITY CHECK)
-- Description : Initial data quality audit on the product catalog table.
-- Purpose     : Check product_id uniqueness, product name consistency,
--               category text cleanliness, and plausibility of price, cost,
--               and rating values before loading into the Silver layer.
-- Scope       :
--   1. Uniqueness and NULL values in product_id.
--   2. Consistency and cleanliness of product_name per product_id.
--   3. Distinct values and text cleanliness for category, subcategory, brand,
--      and supplier.
--   4. Min/max ranges and anomalies in unit_price, product_cost, and
--      product_rating.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- I. CHECK PRIMARY KEY (product_id)
-- Description : Check for product_id values that are NULL or duplicated.
-- Purpose     : Ensure product identifiers are not missing or duplicated.
-- Scope       : product_id and total_rows that are NULL or have more than 1 row.
-- ----------------------------------------------------------------------------
SELECT
    product_id,
    COUNT(*) AS total_rows
FROM bronze_product_catalog
GROUP BY product_id
HAVING product_id IS NULL
    OR COUNT(*) > 1;

-- ----------------------------------------------------------------------------
-- II. CHECK MULTIPLE PRODUCT NAMES PER PRODUCT_ID
--     (or spaces/NULLs)
-- Description : Check name consistency across records for each product_id.
-- Purpose     : Detect inconsistent product names or NULL/whitespace issues.
-- Scope       : Distinct product name count, concatenated product name list, and
--               flags for NULLs, empty strings, or leading/trailing spaces.
-- ----------------------------------------------------------------------------
SELECT
    product_id,
    COUNT(DISTINCT product_name) AS distinct_product_names,
    GROUP_CONCAT(DISTINCT product_name SEPARATOR ' | ') AS product_names
FROM bronze_product_catalog
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1
    OR SUM(CASE WHEN product_name IS NULL OR TRIM(product_name) = '' OR product_name <> TRIM(product_name) THEN 1 ELSE 0 END) > 0;

-- ----------------------------------------------------------------------------
-- III. CHECK CATEGORICAL COLUMNS (category, subcategory, brand, supplier)
-- Description : Check distinct values and text cleanliness across product
--               classification attributes.
-- Purpose     : Find NULL values, empty strings, or leading/trailing spaces.
-- Scope       : Distinct values and status_cek for product_category,
--               product_subcategory, brand, and supplier.
-- ----------------------------------------------------------------------------

-- a. Product Category
SELECT DISTINCT
    product_category,
    CASE
        WHEN product_category IS NULL THEN 'NULL Value'
        WHEN TRIM(product_category) = '' THEN 'Empty String'
        WHEN product_category <> TRIM(product_category) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_product_catalog
ORDER BY product_category;

-- b. Product Subcategory
SELECT DISTINCT
    product_subcategory,
    CASE
        WHEN product_subcategory IS NULL THEN 'NULL Value'
        WHEN TRIM(product_subcategory) = '' THEN 'Empty String'
        WHEN product_subcategory <> TRIM(product_subcategory) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_product_catalog
ORDER BY product_subcategory;

-- c. Brand
SELECT DISTINCT
    brand,
    CASE
        WHEN brand IS NULL THEN 'NULL Value'
        WHEN TRIM(brand) = '' THEN 'Empty String'
        WHEN brand <> TRIM(brand) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_product_catalog
ORDER BY brand;

-- d. Supplier
SELECT DISTINCT
    supplier,
    CASE
        WHEN supplier IS NULL THEN 'NULL Value'
        WHEN TRIM(supplier) = '' THEN 'Empty String'
        WHEN supplier <> TRIM(supplier) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_product_catalog
ORDER BY supplier;

-- ----------------------------------------------------------------------------
-- IV. CHECK NUMERIC COLUMNS (unit_price, product_cost, product_rating)
-- Description : Check min/max values and anomalous counts for unit price,
--               product cost, and rating.
-- Purpose     : Detect zero or negative prices/costs, cost exceeding price,
--               and ratings outside the 0 to 5 scale.
-- Scope       : Min/max values and counts for invalid_unit_price,
--               invalid_product_cost, cost_higher_than_price, and invalid_rating.
-- ----------------------------------------------------------------------------
SELECT
    MIN(unit_price) AS min_unit_price,
    MAX(unit_price) AS max_unit_price,
    MIN(product_cost) AS min_product_cost,
    MAX(product_cost) AS max_product_cost,
    MIN(product_rating) AS min_rating,
    MAX(product_rating) AS max_rating,
    SUM(CASE WHEN unit_price IS NULL OR unit_price <= 0 THEN 1 ELSE 0 END) AS invalid_unit_price,
    SUM(CASE WHEN product_cost IS NULL OR product_cost <= 0 THEN 1 ELSE 0 END) AS invalid_product_cost,
    SUM(CASE WHEN product_cost > unit_price THEN 1 ELSE 0 END) AS cost_higher_than_price,
    SUM(CASE WHEN product_rating IS NULL OR product_rating < 0 OR product_rating > 5 THEN 1 ELSE 0 END) AS invalid_rating
FROM bronze_product_catalog;

-- ============================================================================
-- TABLE 3: BRONZE_ORDER_ITEMS (DATA QUALITY CHECK)
-- Description : Initial data quality audit on the order line items table.
-- Purpose     : Check completeness of order_id & product_id keys, duplicate key
--               pairs, and ranges/anomalies in numeric transaction fields.
-- Scope       :
--   1. order_id and product_id keys that are NULL, empty, or padded with spaces.
--   2. (order_id, product_id) pairs appearing more than once.
--   3. Min/max ranges and anomalies in quantity, unit_price, gross_sales,
--      net_sales, and profit.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- I. CHECK PRIMARY KEYS (order_id & product_id) — NULL, EMPTY, AND SPACES
-- Description : Filter rows where either or both key columns have issues.
-- Purpose     : Ensure order and product references are not NULL, empty, or
--               contain leading/trailing spaces.
-- Scope       : order_id, product_id, and status_cek for rows that are not Clean.
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    product_id,
    CASE
        WHEN order_id IS NULL OR product_id IS NULL THEN 'NULL Key'
        WHEN TRIM(order_id) = '' OR TRIM(product_id) = '' THEN 'Empty Key'
        WHEN order_id <> TRIM(order_id) OR product_id <> TRIM(product_id) THEN 'Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_order_items
WHERE order_id IS NULL
    OR product_id IS NULL
    OR TRIM(order_id) = ''
    OR TRIM(product_id) = ''
    OR order_id <> TRIM(order_id)
    OR product_id <> TRIM(product_id);

-- ----------------------------------------------------------------------------
-- II. CHECK DUPLICATE (order_id, product_id) PAIRS
-- Description : Group records by the combination of order_id and product_id.
-- Purpose     : Detect the same product appearing more than once within the
--               same order_id.
-- Scope       : (order_id, product_id) pairs with total_rows greater than 1.
-- ----------------------------------------------------------------------------

SELECT
    order_id,
    product_id,
    COUNT(*) AS total_rows
FROM bronze_order_items
GROUP BY order_id, product_id
HAVING COUNT(*) > 1
ORDER BY total_rows DESC, order_id, product_id;

-- ----------------------------------------------------------------------------
-- III. CHECK NUMERIC COLUMNS (quantity, price, discount, tax, shipping, sales, profit)
-- Description : Inspect lower/upper bounds and rows with implausible values.
-- Purpose     : Check invalid quantity/price, negative gross_sales, and
--               rows with negative profit.
-- Scope       : Min/max values for quantity, unit_price, gross_sales, net_sales,
--               and profit, plus counts for invalid_qty, invalid_unit_price,
--               negative_gross_sales, and negative_profit_rows.
-- ----------------------------------------------------------------------------

SELECT
    MIN(quantity) AS min_qty,
    MAX(quantity) AS max_qty,
    MIN(unit_price) AS min_unit_price,
    MAX(unit_price) AS max_unit_price,
    MIN(gross_sales) AS min_gross_sales,
    MAX(gross_sales) AS max_gross_sales,
    MIN(net_sales) AS min_net_sales,
    MAX(net_sales) AS max_net_sales,
    MIN(profit) AS min_profit,
    MAX(profit) AS max_profit,
    SUM(CASE WHEN quantity IS NULL OR quantity <= 0 THEN 1 ELSE 0 END) AS invalid_qty,
    SUM(CASE WHEN unit_price IS NULL OR unit_price <= 0 THEN 1 ELSE 0 END) AS invalid_unit_price,
    SUM(CASE WHEN gross_sales IS NULL OR gross_sales < 0 THEN 1 ELSE 0 END) AS negative_gross_sales,
    SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS negative_profit_rows
FROM bronze_order_items;
-- ============================================================================
-- TABLE 4: BRONZE_SALES_TRANSACTION (DATA QUALITY CHECK)
-- Description : Initial data quality audit on the sales transaction table.
-- Purpose     : Check order_id uniqueness, dates/times, transaction status &
--               attributes, shipping/returns/coupons/reviews/loyalty fields,
--               and core financial metrics before loading into the Silver layer.
-- Scope       :
--   1. Uniqueness and cleanliness of the primary key (order_id).
--   2. Completeness of order_date & order_time, and cleanliness/variations
--      across status, channel, customer, location, payment, currency, and
--      shipping columns.
--   3. Value distributions for delivery_days, estimated_delivery_days, returns,
--      coupons, ratings/reviews, marketing_channel, loyalty points, and CLV.
--   4. Min/max ranges and anomalies in quantity, sales, and profit.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CHECK PRIMARY KEY (order_id)
-- Description : Inspect order_id values that are NULL, empty, padded with
--               spaces, or duplicated.
-- Purpose     : Ensure every order_id is unique and valid.
-- Scope       : order_id, status_check, and total_rows matching the HAVING clause.
-- ----------------------------------------------------------------------------

SELECT
    order_id,
    CASE
        WHEN order_id IS NULL THEN 'NULL VALUE'
        WHEN TRIM(order_id) = '' THEN 'Empty String'
        WHEN order_id <> TRIM(order_id) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_check,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
GROUP BY order_id
HAVING order_id IS NULL
    OR COUNT(order_id) > 1
    OR TRIM(order_id) = ''
    OR order_id <> TRIM(order_id);

-- ----------------------------------------------------------------------------
-- 2. CHECK DATE, TIME, & TRANSACTION / PAYMENT / CURRENCY STATUS
-- Description : Check completeness of date/time fields and cleanliness/value
--               variations across transaction dimension columns.
-- Purpose     : Detect NULLs, empty strings, extra spaces, or casing issues
--               in designated columns.
-- Scope       :
--   a. Count of NULL or empty order_date and order_time values.
--   b-g. Values and status_check for order_status, sales_channel, customer_id,
--        customer_name, gender, customer_segment, customer_city, customer_state,
--        customer_country, region, and customer_postal_code.
--   h-k. Distinct values and status_cek for payment_method, payment_status,
--        currency, and shipping_method.
-- ----------------------------------------------------------------------------

-- a. order_date & order_time
SELECT
    SUM(CASE WHEN order_date IS NULL OR TRIM(CAST(order_date AS CHAR)) = '' THEN 1 ELSE 0 END) AS null_or_empty_order_date,
    SUM(CASE WHEN order_time IS NULL OR TRIM(CAST(order_time AS CHAR)) = '' THEN 1 ELSE 0 END) AS null_or_empty_order_time
FROM bronze_sales_transaction;

-- b. order_status
SELECT
    order_status,
    CASE
        WHEN order_status IS NULL THEN 'Null Value'
        WHEN TRIM(order_status) = '' THEN 'Empty String'
        WHEN order_status <> TRIM(order_status) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_check
FROM bronze_sales_transaction
GROUP BY order_status, status_check;

-- c. sales_channel
SELECT
    sales_channel,
    CASE
        WHEN sales_channel IS NULL THEN 'Null Value'
        WHEN TRIM(sales_channel) = '' THEN 'Empty String'
        WHEN sales_channel <> TRIM(sales_channel) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_check
FROM bronze_sales_transaction
GROUP BY sales_channel, status_check;

-- d. customer_id
SELECT
    order_id
    customer_id,
    COUNT(*) AS total_transaksi,
    CASE
        WHEN customer_id IS NULL THEN 'Null Value'
        WHEN TRIM(customer_id) = '' THEN 'Empty String'
        WHEN customer_id <> TRIM(customer_id) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_check
FROM bronze_sales_transaction
GROUP BY
    order_id, customer_id, status_check
ORDER BY total_transaksi DESC;

-- e. customer_name
SELECT
    order_id
    customer_name,
    COUNT(*) AS total_transaksi,
    CASE
        WHEN customer_name IS NULL THEN 'Null Value'
        WHEN TRIM(customer_name) = '' THEN 'Empty String'
        WHEN customer_name <> TRIM(customer_name) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_check
FROM bronze_sales_transaction
GROUP BY
    order_id, customer_name, status_check
ORDER BY total_transaksi DESC;

-- f.1 Gender: check category variations, NULLs, and leading/trailing spaces
SELECT DISTINCT
    gender,
    CASE
        WHEN gender IS NULL THEN 'NULL Value'
        WHEN TRIM(gender) = '' THEN 'Empty String'
        WHEN gender <> TRIM(gender) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY gender;

-- f.2 Customer Segment: check segment variations, NULLs, and leading/trailing spaces
SELECT DISTINCT
    customer_segment,
    CASE
        WHEN customer_segment IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_segment) = '' THEN 'Empty String'
        WHEN customer_segment <> TRIM(customer_segment) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY customer_segment;

-- f.3 Customer City: check city names, NULLs, and leading/trailing spaces
SELECT DISTINCT
    customer_city,
    CASE
        WHEN customer_city IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_city) = '' THEN 'Empty String'
        WHEN customer_city <> TRIM(customer_city) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY customer_city;

-- f.4 Customer State: check state/province names, NULLs, and leading/trailing spaces
SELECT DISTINCT
    customer_state,
    CASE
        WHEN customer_state IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_state) = '' THEN 'Empty String'
        WHEN customer_state <> TRIM(customer_state) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY customer_state;

-- f.5 Customer Country: check country names, NULLs, and leading/trailing spaces
SELECT DISTINCT
    customer_country,
    CASE
        WHEN customer_country IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_country) = '' THEN 'Empty String'
        WHEN customer_country <> TRIM(customer_country) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY customer_country;

-- f.6 Region: check region values, NULLs, and leading/trailing spaces
SELECT DISTINCT
    region,
    CASE
        WHEN region IS NULL THEN 'NULL Value'
        WHEN TRIM(region) = '' THEN 'Empty String'
        WHEN region <> TRIM(region) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY region;

-- g. Postal_Code: check NULLs, duplicates, and leading/trailing spaces
SELECT
    customer_postal_code,
    COUNT(DISTINCT customer_id) AS total_customer,
    CASE
        WHEN customer_postal_code IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_postal_code) = '' THEN 'Empty String'
        WHEN customer_postal_code <> TRIM(customer_postal_code) THEN 'Has Leading/Trailing Space'
        WHEN COUNT(DISTINCT customer_id) > 1 THEN 'Duplicated'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
GROUP BY customer_postal_code
HAVING COUNT(DISTINCT customer_id) > 1
ORDER BY total_customer DESC, customer_postal_code;

-- h. payment_method
SELECT DISTINCT
    payment_method,
    CASE
        WHEN payment_method IS NULL THEN 'NULL Value'
        WHEN TRIM(payment_method) = '' THEN 'Empty String'
        WHEN payment_method <> TRIM(payment_method) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY payment_method;

-- i. payment_status
SELECT DISTINCT
    payment_status,
    CASE
        WHEN payment_status IS NULL THEN 'NULL Value'
        WHEN TRIM(payment_status) = '' THEN 'Empty String'
        WHEN payment_status <> TRIM(payment_status) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY payment_status;

-- j. currency
SELECT DISTINCT
    currency,
    CASE
        WHEN currency IS NULL THEN 'NULL Value'
        WHEN TRIM(currency) = '' THEN 'Empty String'
        WHEN currency <> TRIM(currency) THEN 'Has Leading/Trailing Space'
        WHEN currency <> UPPER(currency) THEN 'Has Upper Issue'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY payment_status;

-- k. shipping_method
SELECT DISTINCT
    shipping_method,
    CASE
        WHEN shipping_method IS NULL THEN 'NULL Value'
        WHEN TRIM(shipping_method) = '' THEN 'Empty String'
        WHEN shipping_method <> TRIM(shipping_method) THEN 'Has Leading/Trailing Space'
        WHEN shipping_method <> UPPER(shipping_method) THEN 'Has Upper Issue'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY shipping_method;

-- ----------------------------------------------------------------------------
-- 3. CHECK CONTEXTUAL & SUPPORTING COLUMNS
--    (delivery_days, estimated_delivery_days, return, coupon, review,
--     marketing_channel, loyalty_points, clv)
-- Description : Review row distributions and value conditions across shipping,
--               returns, coupons, reviews, marketing, and loyalty columns.
-- Purpose     : Understand expected NULL/empty patterns and detect negative
--               values or anomalies in supporting metrics.
-- Scope       :
--   - Row counts per value for delivery_days, estimated_delivery_days,
--     return_status, return_reason, coupon_code, customer_rating,
--     review_sentiment, and customer_review.
--   - Distinct values and status_cek for marketing_channel.
--   - Negative value combinations in loyalty_points_earned & redeemed, and
--     customer_lifetime_value, is_repeat_customer, & customer_order_count.
-- ----------------------------------------------------------------------------

SELECT
    delivery_days,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
GROUP BY delivery_days
ORDER BY total_rows DESC;

SELECT
    estimated_delivery_days,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
GROUP BY estimated_delivery_days
ORDER BY total_rows DESC;

SELECT
    return_status,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
GROUP BY return_status
ORDER BY total_rows DESC;

SELECT
    return_reason,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
GROUP BY return_reason
ORDER BY total_rows DESC;

SELECT
    coupon_code,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
GROUP BY coupon_code
ORDER BY total_rows DESC;

SELECT
    DISTINCT customer_rating,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
GROUP BY customer_rating
ORDER BY total_rows DESC;

SELECT
    DISTINCT review_sentiment,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
GROUP BY review_sentiment
ORDER BY total_rows DESC;

SELECT
    DISTINCT customer_review,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
GROUP BY customer_review
ORDER BY total_rows DESC;

SELECT DISTINCT
    marketing_channel,
    CASE
        WHEN marketing_channel IS NULL THEN 'NULL Value'
        WHEN TRIM(marketing_channel) = '' THEN 'Empty String'
        WHEN marketing_channel <> TRIM(marketing_channel) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_sales_transaction
ORDER BY marketing_channel;

SELECT
    DISTINCT loyalty_points_earned,
    loyalty_points_redeemed,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
WHERE loyalty_points_earned < 0 AND loyalty_points_redeemed < 0
GROUP BY loyalty_points_earned, loyalty_points_redeemed
ORDER BY total_rows DESC;

SELECT
    customer_lifetime_value,
    is_repeat_customer,
    customer_order_count,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
WHERE customer_lifetime_value < 0 OR is_repeat_customer < 0 OR customer_order_count < 0
GROUP BY customer_lifetime_value
ORDER BY total_rows DESC;

-- ----------------------------------------------------------------------------
-- 4. CHECK CORE NUMERIC COLUMNS (quantity, gross_sales, net_sales, profit, margin)
-- Description : Summary of value ranges and primary financial anomalies in
--               transactions.
-- Purpose     : Ensure quantity, gross/net sales, profit, and margin fall
--               within processable ranges.
-- Scope       : Min/max values for quantity, gross_sales, net_sales, profit, and
--               profit_margin_percentage, plus counts for invalid_qty and
--               negative_profit_rows.
-- ----------------------------------------------------------------------------

SELECT
    MIN(quantity) AS min_qty,
    MAX(quantity) AS max_qty,
    MIN(gross_sales) AS min_gross_sales,
    MAX(gross_sales) AS max_gross_sales,
    MIN(net_sales) AS min_net_sales,
    MAX(net_sales) AS max_net_sales,
    MIN(profit) AS min_profit,
    MAX(profit) AS max_profit,
    MIN(profit_margin_percentage) AS min_margin_pct,
    MAX(profit_margin_percentage) AS max_margin_pct,
    SUM(CASE WHEN quantity IS NULL OR quantity <= 0 THEN 1 ELSE 0 END) AS invalid_qty,
    SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS negative_profit_rows
FROM bronze_sales_transaction;
