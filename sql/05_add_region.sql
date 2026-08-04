-- Thêm cột khu vực cho dễ nhận biết khu vực bang
ALTER TABLE gold.dim_customers ADD COLUMN customer_region VARCHAR(20);
-- Mapping tên các bang của Brazil vào đúng khu vực địa lí
UPDATE gold.dim_customers SET customer_region = CASE
    WHEN customer_state IN ('SP','RJ','MG','ES')               THEN 'Southeast'
    WHEN customer_state IN ('RS','SC','PR')                    THEN 'South'
    WHEN customer_state IN ('BA','SE','AL','PE','PB','RN','CE','PI','MA') THEN 'Northeast'
    WHEN customer_state IN ('MT','MS','GO','DF')               THEN 'Central-West'
    WHEN customer_state IN ('AM','PA','AC','RO','RR','AP','TO') THEN 'North'
    ELSE 'Unknown'
END;

