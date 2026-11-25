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





SELECT
	-- demografi & segment
	c.customer_id,
    c.customer_name,
    c.gender,
    c.customer_segment,
    COALESCE(TRIM(s.customer_type), 'Prospect') AS customer_type
    -- geografi
    c.region,
    c.customer_country,
    c.customer_state,
    c.customer_city,
    c.customer_postal_code,
    -- status & nilai crm
    c.customer_acquisition_cost,
    s.customer_lifetime_value,
    s.is_repeat_customer,
    s.customer_order_count
FROM silver_customer_master c
LEFT JOIN silver_sales_transaction s
    ON c.customer_id = s.customer_id
HAVING MAX(s.order_date)    

