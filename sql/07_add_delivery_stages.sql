-- =====================================================================
-- 07 — Phân rã thời gian giao hàng thành 3 khâu (delivery stage breakdown)
-- Mục đích: xác định khâu nào trong quy trình giao hàng gây chậm trễ.
-- Nguồn: bronze olist_orders (gold.fact_orders chỉ giữ tổng số ngày,
--        các mốc trung gian approved_at / delivered_carrier_date nằm ở bronze).
-- Chạy SAU file 03 (load gold). An toàn chạy lại nhiều lần.
-- =====================================================================

-- 1. Thêm 3 cột phân rã (bỏ qua nếu đã tồn tại)
ALTER TABLE gold.fact_orders
    ADD COLUMN IF NOT EXISTS days_approval NUMERIC(6,2),   -- đặt hàng -> duyệt thanh toán
    ADD COLUMN IF NOT EXISTS days_dispatch NUMERIC(6,2),   -- duyệt -> seller giao cho carrier
    ADD COLUMN IF NOT EXISTS days_transit  NUMERIC(6,2);   -- carrier -> tới tay khách

-- 2. Tính từ 4 mốc thời gian ở bronze
-- Dùng hiệu timestamp (giây) chia 86400 để giữ phần lẻ trong ngày,
-- chính xác hơn hiệu 2 ngày lịch ở các khâu ngắn (duyệt thanh toán < 1 ngày).
UPDATE gold.fact_orders f
SET days_approval = ROUND(EXTRACT(EPOCH FROM (o.order_approved_at            - o.order_purchase_timestamp))   / 86400.0, 2),
    days_dispatch = ROUND(EXTRACT(EPOCH FROM (o.order_delivered_carrier_date - o.order_approved_at))          / 86400.0, 2),
    days_transit  = ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date- o.order_delivered_carrier_date))/ 86400.0, 2)
FROM olist_orders o
WHERE f.order_id = o.order_id
  AND o.order_approved_at             IS NOT NULL
  AND o.order_delivered_carrier_date  IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL;

-- 3. NGHIỆM THU
-- 3a. Số đơn có đủ 3 khâu (kỳ vọng ~96,455 — vài chục đơn thiếu mốc trung gian sẽ để NULL)
SELECT COUNT(*) AS don_du_3_khau
FROM gold.fact_orders
WHERE days_transit IS NOT NULL;

-- 3b. Trung bình từng khâu (kỳ vọng: 0.43 / 2.80 / 9.33, tổng ~12.56)
SELECT ROUND(AVG(days_approval), 2) AS tb_duyet_thanh_toan,
       ROUND(AVG(days_dispatch), 2) AS tb_seller_giao_carrier,
       ROUND(AVG(days_transit),  2) AS tb_van_chuyen,
       ROUND(AVG(days_approval + days_dispatch + days_transit), 2) AS tong
FROM gold.fact_orders
WHERE days_transit IS NOT NULL;

-- 3c. So sánh đơn trễ vs đúng hẹn — khâu nào gây ra chênh lệch
-- Kỳ vọng: đúng hẹn ~10.9 ngày, trễ ~31.5 ngày; chênh lệch chủ yếu ở days_transit (~86%)
SELECT CASE WHEN order_delay_day > 0 THEN 'Late' ELSE 'On time' END AS trang_thai,
       COUNT(*)                        AS so_don,
       ROUND(AVG(days_approval), 2)    AS duyet_thanh_toan,
       ROUND(AVG(days_dispatch), 2)    AS seller_giao_carrier,
       ROUND(AVG(days_transit),  2)    AS van_chuyen,
       ROUND(AVG(order_delivery_day),2) AS tong_ngay_giao
FROM gold.fact_orders
WHERE days_transit IS NOT NULL
GROUP BY 1;
