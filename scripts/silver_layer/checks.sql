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


