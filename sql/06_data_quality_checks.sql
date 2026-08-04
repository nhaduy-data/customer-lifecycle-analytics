-- =====================================================================
-- DATA QUALITY CHECKS — Gold Layer reconciliation
-- Mục đích: chứng minh pipeline Bronze -> Gold không mất/nhân bản dữ liệu.
-- Chạy sau mỗi lần build lại Gold. Mọi check phải trả về PASS.
-- =====================================================================

-- ---------- 1. ROW COUNT các bảng Dimension ----------
-- Kỳ vọng: dim = số bản ghi distinct ở nguồn.
SELECT 'dim_customers' AS bang,
       (SELECT COUNT(*) FROM gold.dim_customers)                       AS gold_rows,
       (SELECT COUNT(DISTINCT customer_unique_id) FROM olist_customers) AS nguon,
       CASE WHEN (SELECT COUNT(*) FROM gold.dim_customers)
               = (SELECT COUNT(DISTINCT customer_unique_id) FROM olist_customers)
            THEN 'PASS' ELSE 'FAIL' END AS status
UNION ALL
SELECT 'dim_products',
       (SELECT COUNT(*) FROM gold.dim_products),
       (SELECT COUNT(*) FROM olist_products),
       CASE WHEN (SELECT COUNT(*) FROM gold.dim_products)
               = (SELECT COUNT(*) FROM olist_products)
            THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'dim_sellers',
       (SELECT COUNT(*) FROM gold.dim_sellers),
       (SELECT COUNT(*) FROM olist_sellers),
       CASE WHEN (SELECT COUNT(*) FROM gold.dim_sellers)
               = (SELECT COUNT(*) FROM olist_sellers)
            THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'dim_date (791 ngày)',
       (SELECT COUNT(*) FROM gold.dim_date),
       791,
       CASE WHEN (SELECT COUNT(*) FROM gold.dim_date) = 791
            THEN 'PASS' ELSE 'FAIL' END;

-- ---------- 2. ROW COUNT Fact_Orders ----------
-- Kỳ vọng: 96,477 (= 96,478 đơn delivered - 1 đơn mồ côi không có payment record).
SELECT 'fact_orders' AS bang,
       (SELECT COUNT(*) FROM gold.fact_orders) AS gold_rows,
       96477 AS ky_vong,
       CASE WHEN (SELECT COUNT(*) FROM gold.fact_orders) = 96477
            THEN 'PASS' ELSE 'FAIL' END AS status;

-- ---------- 3. SUM RECONCILIATION doanh thu ----------
-- Kỳ vọng: tổng payment_value ở Fact_Orders = tổng payments của các đơn có trong Fact_Orders.
SELECT 'revenue_reconciliation' AS check_name,
       (SELECT ROUND(SUM(total_payment_value), 2) FROM gold.fact_orders)          AS gold_sum,
       (SELECT ROUND(SUM(p.payment_value), 2)
          FROM olist_order_payments p
         WHERE p.order_id IN (SELECT order_id FROM gold.fact_orders))              AS bronze_sum,
       CASE WHEN (SELECT ROUND(SUM(total_payment_value),2) FROM gold.fact_orders)
               = (SELECT ROUND(SUM(p.payment_value),2) FROM olist_order_payments p
                   WHERE p.order_id IN (SELECT order_id FROM gold.fact_orders))
            THEN 'PASS' ELSE 'FAIL' END AS status;

-- ---------- 4. ORPHAN KEYS — FK trong Fact không tồn tại ở Dim ----------
-- Kỳ vọng: tất cả = 0 (không có khóa mồ côi).
SELECT 'orphan: fact_orders.customer -> dim_customers' AS check_name,
       COUNT(*) AS orphan_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM gold.fact_orders f
LEFT JOIN gold.dim_customers d ON f.customer_unique_id = d.customer_unique_id
WHERE d.customer_unique_id IS NULL
UNION ALL
SELECT 'orphan: fact_order_items.product -> dim_products',
       COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gold.fact_order_items f
LEFT JOIN gold.dim_products d ON f.product_id = d.product_id
WHERE d.product_id IS NULL
UNION ALL
SELECT 'orphan: fact_order_items.seller -> dim_sellers',
       COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gold.fact_order_items f
LEFT JOIN gold.dim_sellers d ON f.seller_id = d.seller_id
WHERE d.seller_id IS NULL
UNION ALL
SELECT 'orphan: fact_rfm_segments.customer -> dim_customers',
       COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gold.fact_rfm_segments f
LEFT JOIN gold.dim_customers d ON f.customer_unique_id = d.customer_unique_id
WHERE d.customer_unique_id IS NULL;

-- ---------- 5. PRIMARY KEY uniqueness (grain integrity) ----------
-- Kỳ vọng: 0 dòng trùng khóa (grain không bị vỡ).
SELECT 'pk_dup: fact_orders(order_id)' AS check_name,
       COUNT(*) AS duplicate_keys,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (SELECT order_id FROM gold.fact_orders GROUP BY order_id HAVING COUNT(*) > 1) t
UNION ALL
SELECT 'pk_dup: fact_order_items(order_id,order_item_id)',
       COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT order_id, order_item_id FROM gold.fact_order_items
      GROUP BY order_id, order_item_id HAVING COUNT(*) > 1) t
UNION ALL
SELECT 'pk_dup: fact_rfm_segments(customer,snapshot)',
       COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT customer_unique_id, snapshot_date FROM gold.fact_rfm_segments
      GROUP BY customer_unique_id, snapshot_date HAVING COUNT(*) > 1) t;
