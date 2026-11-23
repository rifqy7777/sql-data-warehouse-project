USE data_warehouse_ecommerce;

-- ============================================================================
-- TABEL 1: BRONZE_CUSTOMER_MASTER (DATA QUALITY CHECK)
-- Keterangan : Audit kualitas data awal pada tabel master pelanggan.
-- Tujuan     : Mengecek keunikan primary key, nilai NULL/kosong, spasi berlebih,
--              serta kewajaran nilai numerik sebelum masuk ke Silver layer.
-- Dianalisa  :
--   1. Keunikan dan kebersihan primary key (customer_id).
--   2. Kebersihan dan potensi duplikasi nama pelanggan (customer_name).
--   3. Variasi nilai, NULL, string kosong, spasi berlebih, dan sebaran kode pos
--      pada kolom kategorikal & lokasi.
--   4. Rentang nilai minimum/maksimum serta anomali pada umur dan CAC.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- I. CEK PRIMARY KEY (customer_id)
-- Keterangan : Memeriksa apakah customer_id memiliki nilai NULL, kosong, spasi
--              berlebih, atau muncul lebih dari satu baris.
-- Tujuan     : Memastikan setiap baris pelanggan teridentifikasi secara unik.
-- Dianalisa  : Baris dengan customer_id NULL, string kosong, spasi di awal/akhir,
--              atau total_rows lebih dari 1.
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
-- Keterangan : Memeriksa kondisi teks dan potensi duplikasi pada customer_name.
-- Tujuan     : Mendeteksi nama pelanggan yang kosong, berspasi berlebih, atau
--              berulang/berbeda dalam cakupan kueri.
-- Dianalisa  : customer_id, customer_name, serta status_cek untuk string kosong,
--              spasi di awal/akhir, dan kondisi kemunculan ganda.
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
-- III. CEK KOLOM KATEGORIKAL & LOKASI
--      (gender, segment, city, state, country, region, postal_code)
-- Keterangan : Meninjau nilai unik dan kondisi kebersihan teks pada atribut
--              demografi serta alamat pelanggan.
-- Tujuan     : Mengetahui variasi kategori, nilai kosong/NULL, spasi berlebih,
--              dan pemakaian kode pos pada beberapa customer.
-- Dianalisa  : Nilai unik dan status_cek untuk gender, customer_segment,
--              customer_city, customer_state, customer_country, dan region,
--              serta jumlah customer unik per customer_postal_code.
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

-- g. Postal_Code: cek NULL, duplicated, dan spasi berlebih
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
-- IV. CEK KOLOM NUMERIK (customer_age & customer_acquisition_cost)
-- Keterangan : Ringkasan statistik dasar dan penghitungan anomali numerik.
-- Tujuan     : Memastikan nilai umur dan biaya akuisisi pelanggan berada pada
--              rentang yang wajar dan tidak banyak yang NULL/negatif.
-- Dianalisa  : Nilai min/max serta jumlah anomali pada customer_age (NULL,
--              kurang dari 15, atau lebih dari 100) dan customer_acquisition_cost
--              (NULL atau kurang dari 0).
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
-- Keterangan : Audit kualitas data awal pada tabel katalog produk.
-- Tujuan     : Mengecek keunikan product_id, konsistensi nama produk,
--              kebersihan teks kategori, serta kewajaran angka harga, biaya,
--              dan rating sebelum masuk ke Silver layer.
-- Dianalisa  :
--   1. Keunikan dan nilai NULL pada product_id.
--   2. Konsistensi dan kebersihan product_name per product_id.
--   3. Nilai unik dan kebersihan teks pada kategori, subkategori, brand,
--      dan supplier.
--   4. Rentang min/max serta anomali pada unit_price, product_cost, dan
--      product_rating.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- I. CEK PRIMARY KEY (product_id)
-- Keterangan : Mengecek product_id yang bernilai NULL atau muncul ganda.
-- Tujuan     : Memastikan identitas produk tidak kosong atau terduplikasi.
-- Dianalisa  : product_id dan total_rows yang NULL atau lebih dari 1 baris.
-- ----------------------------------------------------------------------------
SELECT
    product_id,
    COUNT(*) AS total_rows
FROM bronze_product_catalog
GROUP BY product_id
HAVING product_id IS NULL
    OR COUNT(*) > 1;

-- ----------------------------------------------------------------------------
-- II. CEK SATU PRODUCT_ID MEMILIKI LEBIH DARI SATU PRODUCT_NAME
--     (atau spasi/NULL)
-- Keterangan : Memeriksa keseragaman nama produk pada setiap product_id.
-- Tujuan     : Mendeteksi inkonsistensi nama produk atau masalah NULL/spasi.
-- Dianalisa  : Jumlah nama produk unik, gabungan daftar nama produk, serta
--              indikasi NULL, string kosong, atau spasi berlebih.
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
-- Keterangan : Mengecek nilai unik serta status kebersihan teks pada atribut
--              klasifikasi produk.
-- Tujuan     : Menemukan nilai NULL, string kosong, atau spasi di awal/akhir.
-- Dianalisa  : Nilai unik dan status_cek untuk product_category,
--              product_subcategory, brand, dan supplier.
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
-- Keterangan : Mengecek nilai min/max serta jumlah nilai tidak wajar pada
--              harga jual, biaya pokok produk, dan rating.
-- Tujuan     : Mendeteksi harga/biaya nol atau negatif, biaya melebihi harga,
--              dan rating di luar skala 0 sampai 5.
-- Dianalisa  : Nilai min/max serta jumlah baris invalid_unit_price,
--              invalid_product_cost, cost_higher_than_price, dan invalid_rating.
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
-- Keterangan : Audit kualitas data awal pada tabel detail item pesanan.
-- Tujuan     : Mengecek kelengkapan kunci order_id & product_id, pasangan
--              kunci ganda, serta rentang dan anomali nilai numerik transaksi.
-- Dianalisa  :
--   1. Kunci order_id dan product_id yang NULL, kosong, atau berspasi.
--   2. Pasangan (order_id, product_id) yang muncul lebih dari satu kali.
--   3. Rentang min/max serta jumlah anomali pada quantity, unit_price,
--      gross_sales, net_sales, dan profit.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- I. CEK KUNCI UTAMA (order_id & product_id) — NULL, KOSONG, DAN SPASI
-- Keterangan : Menyaring baris yang salah satu atau kedua kuncinya bermasalah.
-- Tujuan     : Memastikan relasi order dan produk tidak NULL, kosong, atau
--              mengandung spasi di awal/akhir.
-- Dianalisa  : order_id, product_id, dan status_cek pada baris yang tidak Clean.
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
-- Keterangan : Mengelompokkan berdasarkan kombinasi order_id dan product_id.
-- Tujuan     : Mendeteksi item produk yang sama muncul lebih dari sekali dalam
--              satu order_id yang sama.
-- Dianalisa  : Pasangan (order_id, product_id) dengan total_rows lebih dari 1.
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
-- Keterangan : Melihat batas bawah/atas serta baris dengan nilai tidak wajar.
-- Tujuan     : Mengecek kuantitas/harga tidak valid, gross_sales negatif, dan
--              jumlah baris dengan profit negatif.
-- Dianalisa  : Nilai min/max quantity, unit_price, gross_sales, net_sales,
--              dan profit, serta jumlah invalid_qty, invalid_unit_price,
--              negative_gross_sales, dan negative_profit_rows.
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
-- Keterangan : Audit kualitas data awal pada tabel transaksi penjualan.
-- Tujuan     : Mengecek keunikan order_id, tanggal/waktu, status & atribut
--              transaksi, kolom pengiriman/retur/kupon/ulasan/loyalitas,
--              serta metrik finansial utama sebelum masuk ke Silver layer.
-- Dianalisa  :
--   1. Keunikan dan kebersihan primary key (order_id).
--   2. Kelengkapan order_date & order_time serta kebersihan/variasi kolom
--      status, channel, pelanggan, lokasi, pembayaran, mata uang, dan kirim.
--   3. Distribusi nilai pada delivery_days, estimated_delivery_days, retur,
--      kupon, rating/ulasan, marketing_channel, poin loyalitas, dan CLV.
--   4. Rentang min/max serta anomali pada kuantitas, penjualan, dan profit.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CEK PRIMARY KEY (order_id)
-- Keterangan : Memeriksa order_id yang NULL, kosong, berspasi, atau ganda.
-- Tujuan     : Memastikan setiap order_id unik dan valid.
-- Dianalisa  : order_id, status_check, dan total_rows yang memenuhi syarat HAVING.
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
-- 2. CEK TANGGAL, WAKTU, & STATUS TRANSAKSI / PEMBAYARAN / MATA UANG
-- Keterangan : Memeriksa kelengkapan tanggal/waktu dan kebersihan/variasi
--              nilai pada berbagai kolom dimensi transaksi.
-- Tujuan     : Mendeteksi nilai NULL, string kosong, spasi berlebih, atau
--              ketidaksesuaian huruf kapital pada kolom tertentu.
-- Dianalisa  :
--   a. Jumlah order_date dan order_time yang NULL atau kosong.
--   b-g. Nilai dan status_check pada order_status, sales_channel, customer_id,
--        customer_name, gender, customer_segment, customer_city, customer_state,
--        customer_country, region, serta customer_postal_code.
--   h-k. Nilai unik dan status_cek pada payment_method, payment_status,
--        currency, dan shipping_method.
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

-- f.1 Gender: cek variasi kategori, NULL, dan spasi berlebih
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

-- f.2 Customer Segment: cek variasi segmen pelanggan, NULL, dan spasi berlebih
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

-- f.3 Customer City: cek nama kota, NULL, dan spasi berlebih
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

-- f.4 Customer State: cek provinsi/negara bagian, NULL, dan spasi berlebih
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

-- f.5 Customer Country: cek negara, NULL, dan spasi berlebih
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

-- f.6 Region: cek wilayah/region, NULL, dan spasi berlebih
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

-- g. Postal_Code: cek NULL, duplicated, dan spasi berlebih
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
-- 3. CEK KOLOM KONTEKSTUAL & PENDUKUNG
--    (delivery_days, estimated_delivery_days, return, coupon, review,
--     marketing_channel, loyalty_points, clv)
-- Keterangan : Meninjau distribusi jumlah baris dan kondisi nilai pada kolom
--              pengiriman, retur, kupon, ulasan, pemasaran, serta loyalitas.
-- Tujuan     : Memahami pola nilai kosong/NULL yang wajar maupun mendeteksi
--              nilai negatif/anomali pada metrik pendukung.
-- Dianalisa  :
--   - Jumlah baris per nilai pada delivery_days, estimated_delivery_days,
--     return_status, return_reason, coupon_code, customer_rating,
--     review_sentiment, dan customer_review.
--   - Nilai unik dan status_cek pada marketing_channel.
--   - Kombinasi nilai negatif pada loyalty_points_earned & redeemed serta
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
-- 4. CEK KOLOM NUMERIK UTAMA (quantity, gross_sales, net_sales, profit, margin)
-- Keterangan : Ringkasan rentang nilai dan anomali finansial utama transaksi.
-- Tujuan     : Memastikan nilai kuantitas, penjualan kotor/bersih, profit, dan
--              margin berada dalam rentang yang dapat diproses.
-- Dianalisa  : Nilai min/max quantity, gross_sales, net_sales, profit, dan
--              profit_margin_percentage, serta jumlah invalid_qty dan
--              negative_profit_rows.
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
