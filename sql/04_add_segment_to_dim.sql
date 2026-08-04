--thêm cột vào bảng 
ALTER TABLE gold.dim_customers ADD COLUMN current_segment VARCHAR(50);
-- đổ nhãn segment từ fact_rfm_segments
WITH latest AS (
    SELECT customer_unique_id, segment_name,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id 
                              ORDER BY snapshot_date DESC) AS rn
    FROM gold.fact_rfm_segments
)
UPDATE gold.dim_customers d
SET current_segment = l.segment_name
FROM latest l
WHERE d.customer_unique_id = l.customer_unique_id
  AND l.rn = 1;
-- nghiệm thu
SELECT current_segment, COUNT(*) 
FROM gold.dim_customers 
GROUP BY current_segment;
-- update tên cột null
UPDATE gold.dim_customers
SET current_segment = 'No Completed Order'
WHERE current_segment IS NULL;