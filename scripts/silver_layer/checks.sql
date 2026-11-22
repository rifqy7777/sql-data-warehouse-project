USE data_warehouse_ecommerce;

-- ============================================================================
-- TABEL 1: BRONZE_CUSTOMER_MASTER (DATA QUALITY CHECK)
-- Tujuan: Mengecek keunikan primary key, nilai NULL/kosong, spasi berlebih,
--         dan kewajaran nilai numerik sebelum masuk ke tahap pembersihan/Silver.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- I. CEK PRIMARY KEY (customer_id)
-- Memastikan customer_id tidak NULL dan tidak ada baris ganda (duplikat).
-- ----------------------------------------------------------------------------
SELECT
    customer_id,
    COUNT(*) AS total_rows
FROM bronze_customer_master
GROUP BY customer_id
HAVING customer_id IS NULL
    OR COUNT(*) > 1;


-- ----------------------------------------------------------------------------
-- II. CEK NAMA PELANGGAN (customer_name)
-- Mendeteksi customer_name yang bernilai NULL, string kosong, atau punya spasi
-- di awal/akhir teks.
-- ----------------------------------------------------------------------------
SELECT
    customer_id,
    customer_name,
    CASE
        WHEN customer_name IS NULL THEN 'NULL Value'
        WHEN TRIM(customer_name) = '' THEN 'Empty String'
        WHEN customer_name <> TRIM(customer_name) THEN 'Has Leading/Trailing Space'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_customer_master
WHERE customer_name IS NULL
   OR TRIM(customer_name) = ''
   OR customer_name <> TRIM(customer_name);


-- ----------------------------------------------------------------------------
-- III. CEK KOLOM KATEGORIKAL & LOKASI (gender, segment, city, state, country, region)
-- Menampilkan nilai unik beserta status apakah ada NULL, string kosong, atau
-- spasi berlebih di awal/akhir.
-- ----------------------------------------------------------------------------

-- a. Gender: cek variasi kategori, NULL, dan spasi berlebih
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

-- b. Customer Segment: cek variasi segmen pelanggan, NULL, dan spasi berlebih
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

-- c. Customer City: cek nama kota, NULL, dan spasi berlebih
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

-- d. Customer State: cek provinsi/negara bagian, NULL, dan spasi berlebih
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

-- e. Customer Country: cek negara, NULL, dan spasi berlebih
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

-- f. Region: cek wilayah/region, NULL, dan spasi berlebih
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


-- ----------------------------------------------------------------------------
-- IV. CEK KOLOM NUMERIK & KODE POS (customer_age, postal_code, acquisition_cost)
-- Memeriksa rentang nilai minimum/maksimum, NULL, dan potensi outlier/anomali.
-- ----------------------------------------------------------------------------
SELECT
    MIN(customer_age) AS min_age,
    MAX(customer_age) AS max_age,
    SUM(CASE WHEN customer_age IS NULL OR customer_age < 15 OR customer_age > 100 THEN 1 ELSE 0 END) AS age_anomalies,
    SUM(CASE WHEN customer_postal_code IS NULL OR TRIM(CAST(customer_postal_code AS CHAR)) = '' THEN 1 ELSE 0 END) AS postal_code_null_or_empty,
    MIN(customer_acquisition_cost) AS min_cac,
    MAX(customer_acquisition_cost) AS max_cac,
    SUM(CASE WHEN customer_acquisition_cost IS NULL OR customer_acquisition_cost < 0 THEN 1 ELSE 0 END) AS cac_anomalies
FROM bronze_customer_master;

USE data_warehouse_ecommerce;

-- ============================================================================
-- TABEL 2: BRONZE_PRODUCT_CATALOG (DATA QUALITY CHECK)
-- Tujuan: Mengecek keunikan product_id, konsistensi product_name per ID,
--         anomali teks/spasi pada kolom kategorikal, serta kewajaran angka
--         harga, biaya produk, dan rating sebelum masuk ke Silver.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- I. CEK PRIMARY KEY (product_id)
-- Memastikan product_id tidak NULL dan tidak ada baris duplikat.
-- ----------------------------------------------------------------------------
SELECT
    product_id,
    COUNT(*) AS total_rows
FROM bronze_product_catalog
GROUP BY product_id
HAVING product_id IS NULL
    OR COUNT(*) > 1;


-- ----------------------------------------------------------------------------
-- II. CEK SATU PRODUCT_ID MEMILIKI LEBIH DARI SATU PRODUCT_NAME (atau spasi/NULL)
-- Memastikan setiap product_id merepresentasikan satu nama produk yang konsisten.
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
-- III. CEK KOLOM KATEGORIKAL (category, subcategory, brand, supplier)
-- Melihat nilai unik sekaligus mendeteksi NULL, string kosong, atau spasi berlebih.
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
-- IV. CEK KOLOM NUMERIK (unit_price, product_cost, product_rating)
-- Memeriksa nilai min/max, NULL, nilai <= 0, biaya melebihi harga jual,
-- dan rating di luar rentang wajar (0 - 5).
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
