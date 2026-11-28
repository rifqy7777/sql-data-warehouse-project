DELIMITER //

DROP PROCEDURE IF EXISTS sp_load_silver_layer //

CREATE PROCEDURE sp_load_silver_layer()
BEGIN
    DECLARE v_start_time DATETIME(6);
    DECLARE v_end_time DATETIME(6);
    DECLARE v_batch_start DATETIME(6);
    DECLARE v_batch_end DATETIME(6);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT '==========================================' AS log_msg;
        SELECT 'ERROR OCCURRED DURING LOADING SILVER LAYER' AS log_msg;
        SELECT '==========================================' AS log_msg;
    END;

    SET v_batch_start = NOW(6);
    SELECT '================================================' AS log_msg;
    SELECT 'Loading Silver Layer' AS log_msg;
    SELECT '================================================' AS log_msg;

    -- ========================================================================
    -- TABEL 1: SILVER_PRODUCT_CATALOG
    -- Keterangan : Memindahkan data katalog produk dari Bronze ke Silver layer.
    -- Kenapa Silver layer: Merapikan spasi teks, menyeragamkan pembulatan angka
    --              harga/biaya/rating, menyaring product_id kosong, serta
    --              melakukan deduplikasi per product_id agar katalog bersih dan
    --              konsisten sebelum dipakai di tahap analisis/Gold.
    -- ========================================================================
    SET v_start_time = NOW(6);
    SELECT '>> Truncating Table: silver_product_catalog' AS log_msg;
    TRUNCATE TABLE silver_product_catalog;

    SELECT '>> Inserting Data Into: silver_product_catalog' AS log_msg;
    INSERT INTO silver_product_catalog (
        product_id,
        product_name,
        product_category,
        product_subcategory,
        brand,
        supplier,
        unit_price,
        product_cost,
        product_rating,
        data_load_dt
    )
    WITH cleaned_product AS (
        SELECT
            TRIM(product_id) AS product_id,
            TRIM(product_name) AS product_name,
            TRIM(product_category) AS product_category,
            TRIM(product_subcategory) AS product_subcategory,
            TRIM(brand) AS brand,
            TRIM(supplier) AS supplier,
            ROUND(COALESCE(unit_price, 0), 2) AS unit_price,
            ROUND(COALESCE(product_cost, 0), 2) AS product_cost,
            ROUND(COALESCE(product_rating, 0), 1) AS product_rating,
            ROW_NUMBER() OVER (
                PARTITION BY TRIM(product_id)
                ORDER BY product_id
            ) AS rn
        FROM bronze_product_catalog
        WHERE product_id IS NOT NULL
          AND TRIM(product_id) <> ''
    )
    SELECT
        product_id,
        product_name,
        product_category,
        product_subcategory,
        brand,
        supplier,
        unit_price,
        product_cost,
        product_rating,
        CURRENT_TIMESTAMP AS data_load_dt
    FROM cleaned_product
    WHERE rn = 1;

    SET v_end_time = NOW(6);
    SELECT CONCAT('>> Load Duration: ', TIMESTAMPDIFF(SECOND, v_start_time, v_end_time), ' seconds') AS log_msg;
    SELECT '>> -------------' AS log_msg;

    -- ========================================================================
    -- TABEL 2: SILVER_CUSTOMER_MASTER
    -- Keterangan : Memindahkan data master pelanggan dari Bronze ke Silver layer.
    -- Kenapa Silver layer: Membersihkan spasi berlebih pada atribut teks dan
    --              kode pos, membuang customer_id kosong/NULL, serta menjaga
    --              keunikan per customer_id tanpa menghapus entitas yang kebetulan
    --              bernama sama atau memaksakan aturan Gold terlalu dini.
    -- ========================================================================
    SET v_start_time = NOW(6);
    SELECT '>> Truncating Table: silver_customer_master' AS log_msg;
    TRUNCATE TABLE silver_customer_master;

    SELECT '>> Inserting Data Into: silver_customer_master' AS log_msg;
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
        customer_acquisition_cost,
        data_load_dt
    )
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
            TRIM(customer_postal_code) AS customer_postal_code,
            customer_acquisition_cost,
            ROW_NUMBER() OVER (
                PARTITION BY TRIM(customer_id)
                ORDER BY customer_id
            ) AS rn
        FROM bronze_customer_master
        WHERE customer_id IS NOT NULL
          AND TRIM(customer_id) <> ''
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
        customer_acquisition_cost,
        CURRENT_TIMESTAMP AS data_load_dt
    FROM cleaned_customer
    WHERE rn = 1;

    SET v_end_time = NOW(6);
    SELECT CONCAT('>> Load Duration: ', TIMESTAMPDIFF(SECOND, v_start_time, v_end_time), ' seconds') AS log_msg;
    SELECT '>> -------------' AS log_msg;

    -- ========================================================================
    -- TABEL 3: SILVER_SALES_TRANSACTION
    -- Keterangan : Memindahkan data transaksi penjualan dari Bronze ke Silver layer.
    -- Kenapa Silver layer: Menstandarkan spasi, kapitalisasi currency, tipe
    --              numerik/boolean (is_repeat_customer), serta mengubah string
    --              kosong menjadi NULL pada kolom kondisional (retur, kupon,
    --              kampanye, ulasan) sambil mempertahankan nilai NULL vs 0 asli
    --              (seperti pada delivery_days/order batal) agar makna data jujur.
    -- ========================================================================
    SET v_start_time = NOW(6);
    SELECT '>> Truncating Table: silver_sales_transaction' AS log_msg;
    TRUNCATE TABLE silver_sales_transaction;

    SELECT '>> Inserting Data Into: silver_sales_transaction' AS log_msg;
    INSERT INTO silver_sales_transaction (
        order_id,
        order_date,
        order_time,
        order_status,
        sales_channel,
        customer_id,
        customer_name,
        customer_age,
        gender,
        customer_segment,
        customer_type,
        customer_city,
        customer_state,
        customer_country,
        region,
        customer_postal_code,
        payment_method,
        payment_status,
        currency,
        shipping_method,
        warehouse,
        delivery_days,
        estimated_delivery_days,
        delivery_status,
        return_status,
        return_reason,
        customer_rating,
        review_sentiment,
        customer_review,
        marketing_channel,
        campaign_name,
        coupon_code,
        loyalty_points_earned,
        loyalty_points_redeemed,
        quantity,
        gross_sales,
        discount_amount,
        tax_amount,
        shipping_cost,
        net_sales,
        product_cost,
        profit,
        profit_margin_percentage,
        customer_lifetime_value,
        is_repeat_customer,
        customer_order_count,
        data_load_dt
    )
    WITH cleaned_transaction AS (
        SELECT
            TRIM(order_id) AS order_id,
            order_date,
            order_time,
            TRIM(order_status) AS order_status,
            TRIM(sales_channel) AS sales_channel,
            TRIM(customer_id) AS customer_id,
            TRIM(customer_name) AS customer_name,
            customer_age,
            TRIM(gender) AS gender,
            TRIM(customer_segment) AS customer_segment,
            TRIM(customer_type) AS customer_type,
            TRIM(customer_city) AS customer_city,
            TRIM(customer_state) AS customer_state,
            TRIM(customer_country) AS customer_country,
            TRIM(region) AS region,
            TRIM(customer_postal_code) AS customer_postal_code,
            TRIM(payment_method) AS payment_method,
            TRIM(payment_status) AS payment_status,
            UPPER(TRIM(currency)) AS currency,
            TRIM(shipping_method) AS shipping_method,
            TRIM(warehouse) AS warehouse,
            delivery_days,
            estimated_delivery_days,
            TRIM(delivery_status) AS delivery_status,
            NULLIF(TRIM(return_status), '') AS return_status,
            NULLIF(TRIM(return_reason), '') AS return_reason,
            ROUND(customer_rating, 1) AS customer_rating,
            NULLIF(TRIM(review_sentiment), '') AS review_sentiment,
            NULLIF(TRIM(customer_review), '') AS customer_review,
            TRIM(marketing_channel) AS marketing_channel,
            NULLIF(TRIM(campaign_name), '') AS campaign_name,
            NULLIF(TRIM(coupon_code), '') AS coupon_code,
            CAST(COALESCE(loyalty_points_earned, 0) AS SIGNED) AS loyalty_points_earned,
            CAST(COALESCE(loyalty_points_redeemed, 0) AS SIGNED) AS loyalty_points_redeemed,
            CAST(COALESCE(quantity, 0) AS SIGNED) AS quantity,
            ROUND(COALESCE(gross_sales, 0), 2) AS gross_sales,
            ROUND(COALESCE(discount_amount, 0), 2) AS discount_amount,
            ROUND(COALESCE(tax_amount, 0), 2) AS tax_amount,
            ROUND(COALESCE(shipping_cost, 0), 2) AS shipping_cost,
            ROUND(COALESCE(net_sales, 0), 2) AS net_sales,
            ROUND(COALESCE(product_cost, 0), 2) AS product_cost,
            ROUND(COALESCE(profit, 0), 2) AS profit,
            ROUND(COALESCE(profit_margin_percentage, 0), 2) AS profit_margin_percentage,
            ROUND(COALESCE(customer_lifetime_value, 0), 2) AS customer_lifetime_value,
            CASE
                WHEN UPPER(TRIM(CAST(is_repeat_customer AS CHAR))) IN ('1', 'TRUE', 'YES') THEN 1
                ELSE 0
            END AS is_repeat_customer,
            CAST(COALESCE(customer_order_count, 0) AS SIGNED) AS customer_order_count
        FROM bronze_sales_transaction
        WHERE order_id IS NOT NULL
          AND TRIM(order_id) <> ''
    )
    SELECT
        order_id,
        order_date,
        order_time,
        order_status,
        sales_channel,
        customer_id,
        customer_name,
        customer_age,
        gender,
        customer_segment,
        customer_type,
        customer_city,
        customer_state,
        customer_country,
        region,
        customer_postal_code,
        payment_method,
        payment_status,
        currency,
        shipping_method,
        warehouse,
        delivery_days,
        estimated_delivery_days,
        delivery_status,
        return_status,
        return_reason,
        customer_rating,
        review_sentiment,
        customer_review,
        marketing_channel,
        campaign_name,
        coupon_code,
        loyalty_points_earned,
        loyalty_points_redeemed,
        quantity,
        gross_sales,
        discount_amount,
        tax_amount,
        shipping_cost,
        net_sales,
        product_cost,
        profit,
        profit_margin_percentage,
        customer_lifetime_value,
        is_repeat_customer,
        customer_order_count,
        CURRENT_TIMESTAMP AS data_load_dt
    FROM cleaned_transaction;

    SET v_end_time = NOW(6);
    SELECT CONCAT('>> Load Duration: ', TIMESTAMPDIFF(SECOND, v_start_time, v_end_time), ' seconds') AS log_msg;
    SELECT '>> -------------' AS log_msg;

    -- ========================================================================
    -- TABEL 4: SILVER_ORDERS_ITEMS
    -- Keterangan : Memindahkan data detail item pesanan dari Bronze ke Silver.
    -- Kenapa Silver layer: Memastikan order_id dan product_id terisi serta bebas
    --              spasi, merapikan tipe integer dan pembulatan desimal pada
    --              harga, diskon, penjualan, biaya, dan profit, sekaligus
    --              menambahkan waktu muat (data_load_dt) untuk keterlacakan ETL.
    -- ========================================================================
    SET v_start_time = NOW(6);
    SELECT '>> Truncating Table: silver_order_items' AS log_msg;
    TRUNCATE TABLE silver_order_items;

    SELECT '>> Inserting Data Into: silver_order_items' AS log_msg;
    WITH cleaned_order_items AS (
        SELECT
            order_id,
            product_id,
            ROW_NUMBER() OVER (
                PARTITION BY order_id, product_id
                ORDER BY quantity, unit_price, gross_sales, net_sales, profit
            ) AS line_item_seq,
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
            CASE
                WHEN ROUND(net_sales - product_cost - shipping_cost - tax_amount, 2) <> ROUND(profit, 2)
                 AND ROUND(net_sales - product_cost - shipping_cost, 2) <> ROUND(profit, 2)
                 AND ROUND(net_sales - product_cost, 2) <> ROUND(profit, 2)
                THEN 'FORMULA_ANOMALY'
                ELSE 'VALID'
            END AS dq_profit_status
        FROM bronze_order_items
    )
    INSERT INTO silver_order_items (
        order_id,
        product_id,
        line_item_seq,
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
        dq_profit_status,
        dq_loss_driver
    )
    SELECT
        order_id,
        product_id,
        line_item_seq,
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
        dq_profit_status,
        CASE
            WHEN profit >= 0 THEN 'Non-Negative Profit'
            WHEN dq_profit_status = 'FORMULA_ANOMALY' THEN 'Formula Mismatch / Anomaly'
            WHEN product_cost > (unit_price * quantity) THEN 'Base Cost > Gross Sales'
            WHEN discount_percentage > 0.50 OR discount_amount > (gross_sales * 0.50) THEN 'Heavy Discount (>50%)'
            WHEN (net_sales - product_cost) >= 0 AND profit < 0 THEN 'Shipping/Tax Dragged Profit Negative'
            ELSE 'Near-50% Discount / Valid Margin Compression'
        END AS dq_loss_driver
    FROM cleaned_order_items;

    SET v_end_time = NOW(6);
    SELECT CONCAT('>> Load Duration: ', TIMESTAMPDIFF(SECOND, v_start_time, v_end_time), ' seconds') AS log_msg;
    SELECT '>> -------------' AS log_msg;

    SET v_batch_end = NOW(6);
    SELECT '==========================================' AS log_msg;
    SELECT 'Loading Silver Layer is Completed' AS log_msg;
    SELECT CONCAT('   - Total Load Duration: ', TIMESTAMPDIFF(SECOND, v_batch_start, v_batch_end), ' seconds') AS log_msg;
    SELECT '==========================================' AS log_msg;
END //

DELIMITER ;

-- ============================================================================
-- EKSEKUSI & VERIFIKASI HASIL LOAD
-- Keterangan : Menjalankan procedure load Silver lalu mengecek jumlah baris
--              di tiap tabel Silver setelah proses selesai.
-- ============================================================================
CALL sp_load_silver_layer();

SELECT 'silver_product_catalog' AS table_name, COUNT(*) AS total_rows FROM silver_product_catalog
UNION ALL
SELECT 'silver_customer_master', COUNT(*) FROM silver_customer_master
UNION ALL
SELECT 'silver_sales_transaction', COUNT(*) FROM silver_sales_transaction
UNION ALL
SELECT 'silver_order_items', COUNT(*) FROM silver_order_items;
