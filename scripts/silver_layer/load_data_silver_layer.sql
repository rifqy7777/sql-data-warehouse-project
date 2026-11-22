-- ============================================================================
-- TABEL 1: SILVER_CUSTOMER_MASTER 
-- Tujuan: 
--
-- ============================================================================

USE data_warehouse_ecommerce;

-- ============================================================================
-- LOAD & CLEAN: SILVER_CUSTOMER_MASTER 
-- ============================================================================
WITH cleaned_customer AS (
    SELECT
        TRIM(customer_id) AS customer_id,
        TRIM(customer_name) AS customer_name,
        customer_age,
        TRIM(gender) AS gender,
        TRIM(customer_segment) AS customer_segment,
        TRIM(customer_city) AS customer_city,
        TRIM(customer_state) AS customer_state,
        TRIM(customer_country) AS customer_country,
        TRIM(region) AS region,
        TRIM(CAST(customer_postal_code AS CHAR)) AS customer_postal_code,
        ROUND(COALESCE(customer_acquisition_cost, 0), 2) AS customer_acquisition_cost
    FROM bronze_customer_master
    WHERE customer_id IS NOT NULL
      AND TRIM(customer_id) <> ''
)
INSERT INTO silver_customer_master (
    customer_id,
    customer_name,
    customer_age,
    gender,
    customer_segment,
    customer_city,
    customer_state,
    customer_country,
    region,
    customer_postal_code,
    customer_acquisition_cost
)
SELECT
    customer_id,
    customer_name,
    customer_age,
    gender,
    customer_segment,
    customer_city,
    customer_state,
    customer_country,
    region,
    customer_postal_code,
    customer_acquisition_cost
FROM cleaned_customer;
