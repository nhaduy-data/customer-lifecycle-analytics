truncate gold.fact_order_items,
gold.fact_orders,
gold.fact_rfm_segments,
gold.dim_customers,
gold.dim_date,
gold.dim_products,
gold.dim_sellers;

--Load data Dim_Sellers
Insert Into gold.dim_sellers(seller_id,seller_city,seller_state)
select seller_id,seller_city,seller_state
from olist_sellers;

--Load data Dim_Products
INSERT INTO gold.dim_products(product_id,product_category_name,product_category_name_english)
select  p.product_id,
		coalesce(p.product_category_name,'unknown'),
		coalesce (t.product_category_name_english ,'unknown')
from olist_products as p 
left join product_category_name_translation as t on p.product_category_name = t.product_category_name;

-- Load data Dim_Date
with dates as (
select generate_series('2016-09-01'::date , '2018-10-31' :: date , '1 day')::date AS d
)
INSERT INTO gold.dim_date(date_key,date_year,date_month,date_month_name,date_quarter, date_day_of_week, date_is_weekend)
select d, 
	   extract(year from d),
	   extract(month from d),
	   to_char(d,'FMMonth'),
	   extract(quarter from d),
	   to_char(d,'FMDay'),
	   extract(ISODOW from d) >=6
from dates;	 

-- load dim_customers
with customers as (
select c.customer_unique_id ,
c.customer_city , c.customer_state ,
min(o.order_purchase_timestamp) over (partition by c.customer_unique_id) as first_purchase_date,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp desc) as rn
from olist_customers as c
join olist_orders as o on c.customer_id = o.customer_id
--giữ mọi order_status:phục vụ cả phân tích đơn hủy sau này
INSERT INTO gold.dim_customers(customer_unique_id, customer_city , customer_state, first_purchase_date)
select customer_unique_id,customer_city,customer_state,first_purchase_date
from customers 
where rn = 1 ;

-- Load data Fact_Orders :1 dòng là 1 đơn 
with payment_value as (
select order_id, sum(payment_value) as total
from olist_order_payments
group by order_id
), 
freight as ( 
select order_id , sum(freight_value) as total_freight
from olist_order_items 
group by order_id
),
score as (
select order_id, avg(review_score) as avg_score
from olist_order_reviews
group by order_id
),
-- Dominant payment type: mỗi đơn lấy loại thanh toán có payment_value lớn nhất
-- Chấp nhận loại = 0.48% tổng doanh thu để giữ model đơn giản
-- Nếu cần cơ cấu doanh thu theo payment type thì sẽ query thẳng bronze olist_order_payments
pay_type as (
select order_id , payment_type , payment_installments, 
row_number() over(partition by order_id order by payment_value desc) as rn
from olist_order_payments
)
INSERT INTO gold.fact_orders(order_id,order_purchase_date, customer_unique_id,total_payment_value,order_freight,order_review_score, order_delivery_day, order_delay_day, order_payment_type , order_payment_installment)
select o.order_id,
       o.order_purchase_timestamp::date as order_purchase_date,
       c.customer_unique_id,
	   v.total as total_payment_value,
	   f.total_freight as order_freight,
	   s.avg_score as order_review_score,
	   (o.order_delivered_customer_date::date - o.order_purchase_timestamp::date) as order_delivery_day,
	   (o.order_delivered_customer_date:: date - o.order_estimated_delivery_date::date) as order_delay_day,
	   p.payment_type as order_payment_type,
	   p.payment_installments as order_payment_installment
from olist_orders o
join olist_customers c on o.customer_id = c.customer_id
join payment_value v on v.order_id = o.order_id -- INNER JOIN: loại 1 đơn delivered không có payment record , chấp nhận mất 1 đơn để cột tiền không NULL.
join freight f on f.order_id = o.order_id 
left join score s on s.order_id = o.order_id
left join pay_type as p on p.order_id =o.order_id 
where o.order_status = 'delivered' and p.rn=1;

-- Load Fact_Order_Items : 1 dòng = 1 món hàng trong đơn
INSERT INTO gold.fact_order_items(order_item_id,order_id,product_id,seller_id,customer_unique_id,purchase_date,price ,freight_value)
select i.order_item_id,o.order_id,i.product_id,i.seller_id,c.customer_unique_id,(o.order_purchase_timestamp::date) as purchase_date, i.price ,i.freight_value
from olist_order_items i 
join olist_orders o on i.order_id=o.order_id
join olist_customers c on c.customer_id = o.customer_id
where o.order_status = 'delivered' and o.order_id in (select order_id from gold.fact_orders);
