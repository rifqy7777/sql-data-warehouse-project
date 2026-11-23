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
        WHEN COUNT(DISTINCT customer_name) > 1 THEN 'Duplicated'
        ELSE 'Clean'
    END AS status_cek
FROM bronze_customer_master
HAVING COUNT(DISTINCT customer_id) > 1
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

--g. Postal_Code, Null, duplicated dan spasi berlebih

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
-- IV. CEK KOLOM NUMERIK & KODE POS (customer_age, & acquisition_cost)
-- Memeriksa rentang nilai minimum/maksimum, NULL, dan potensi outlier/anomali.
-- ----------------------------------------------------------------------------
SELECT
    MIN(customer_age) AS min_age,
    MAX(customer_age) AS max_age,
    SUM(CASE WHEN customer_age IS NULL OR customer_age < 15 OR customer_age > 100 THEN 1 ELSE 0 END) AS age_anomalies,
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


USE data_warehouse_ecommerce;

-- ============================================================================
-- TABEL 3: BRONZE_ORDER_ITEMS (DATA QUALITY CHECK)
-- Tujuan: Mengecek kelengkapan order_id & product_id, mendeteksi pasangan
--         (order_id, product_id) yang muncul lebih dari sekali, serta memeriksa
--         anomali/rentang nilai numerik sebelum masuk ke tahap Silver.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- I. CEK KUNCI UTAMA (order_id & product_id) — NULL, KOSONG, DAN SPASI
-- Memastikan tidak ada ID yang NULL, string kosong, atau punya spasi berlebih.
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
-- II. CEK PASANGAN (order_id, product_id) YANG GANDA
-- Catatan: 1 order_id punya banyak baris itu normal (multi-item order),
-- tapi kalau (order_id, product_id) sama muncul > 1 kali, perlu dicek detailnya.
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
-- III. CEK KOLOM NUMERIK (quantity, harga, diskon, pajak, ongkir, sales, profit)
-- Melihat rentang min/max, NULL, quantity/harga tidak wajar, dan baris rugi.
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

USE data_warehouse_ecommerce;

-- ============================================================================
-- TABEL 4: BRONZE_SALES_TRANSACTION (DATA QUALITY CHECK)
-- Tujuan: Mengecek keunikan order_id, format tanggal/waktu, status &
--         pengiriman, kolom kosong/retur/kupon, serta kewajaran angka transaksi
--         sebelum masuk ke tahap Silver.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. CEK PRIMARY KEY (order_id)
-- Memastikan setiap order_id unik (1 baris per order) dan tidak NULL/kosong.
-- ----------------------------------------------------------------------------
SELECT order_id,
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
-- 2. CEK TANGGAL, WAKTU, & STATUS TRANSAKSI / PEMBAYARAN / MATA UANG
-- Memastikan order_date & order_time bisa diparse dengan benar serta mengecek
-- nilai unik pada status dan currency.
-- ----------------------------------------------------------------------------
-- a. order_date & order_time
SELECT
    SUM(CASE WHEN order_date IS NULL OR TRIM(CAST(order_date AS CHAR)) = '' THEN 1 ELSE 0 END) AS null_or_empty_order_date,
    SUM(CASE WHEN order_time IS NULL OR TRIM(CAST(order_time AS CHAR)) = '' THEN 1 ELSE 0 END) AS null_or_empty_order_time
FROM bronze_sales_transaction;

-- b.order_status
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

-- c.sales_channel
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

--e. customer_name
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

-- a. Gender: cek variasi kategori, NULL, dan spasi berlebih
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

-- b. Customer Segment: cek variasi segmen pelanggan, NULL, dan spasi berlebih
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

-- c. Customer City: cek nama kota, NULL, dan spasi berlebih
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

-- d. Customer State: cek provinsi/negara bagian, NULL, dan spasi berlebih
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
    
    -- e. Customer Country: cek negara, NULL, dan spasi berlebih
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

-- f. Region: cek wilayah/region, NULL, dan spasi berlebih
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

-- g. Postal_Code, Null, duplicated dan spasi berlebih

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

--h payment method
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

-- i payment status
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

-- shipping method
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
-- 3. CEK KOLOM KONTEKSTUAL YANG SERING KOSONG (return_status, return_reason, coupon_code)
-- Mengecek distribusi nilai termasuk NULL atau string kosong (wajar jika tidak
-- ada retur atau tidak pakai kupon).
-- ----------------------------------------------------------------------------
SELECT 
	delivery_days,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
GROUP BY delivery_days
ORDER BY total_rows DESC;

SELECT 
	estimated_delivery_days ,
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
	customer_lifetime_value, is_repeat_customer, customer_order_count,
    COUNT(*) AS total_rows
FROM bronze_sales_transaction
WHERE customer_lifetime_value < 0 OR is_repeat_customer <0 OR customer_order_count < 0
GROUP BY customer_lifetime_value
ORDER BY total_rows DESC;


-- ----------------------------------------------------------------------------
-- 4. CEK KOLOM NUMERIK UTAMA (quantity, gross_sales, net_sales, profit, margin)
-- Melihat rentang min/max, NULL, dan baris dengan profit/margin negatif.
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
