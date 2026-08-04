create schema if not exists gold;
-- Bang Dim 
create table gold.Dim_Customers(
	customer_unique_id varchar(50) Primary key,
	customer_city varchar(100),
	customer_state varchar(2),
	first_purchase_date date
);
create table gold.Dim_Products(
	product_id varchar(50) primary key,
	product_category_name varchar(100) ,
	product_category_name_english varchar(100)
);
create table gold.Dim_Sellers(
	seller_id varchar(50) primary key,
	seller_city varchar(100),
	seller_state varchar(2)
);
create table gold.Dim_Date(
	date_key Date Primary key,
	date_year integer,
	date_month integer,
	date_month_name varchar(50),
	date_quarter integer,
	date_day_of_week varchar(50),
	date_is_weekend boolean
);
-- Bang Fact
create table gold.Fact_Orders(
	customer_unique_id varchar(50),
	order_id varchar(50) primary key,
	order_purchase_date date,
	total_payment_value numeric(18,2),
	order_freight numeric(18,2),
	order_delivery_day integer,
	order_delay_day integer,
	order_review_score numeric(18,2), -- avg khi đơn có 2+ reviews
	order_payment_type varchar(100),
	order_payment_installment integer,
	Foreign key (order_purchase_date) references gold.Dim_Date(date_key),
	foreign key (customer_unique_id) references gold.Dim_Customers(customer_unique_id)
);
create table gold.Fact_Order_Items(
	order_item_id integer,
	order_id varchar(50),
	product_id varchar(50),
	seller_id varchar(50),
	customer_unique_id VARCHAR(50),
	purchase_date date,
	price numeric(18,2),
	freight_value numeric(10,2), 
	primary key (order_id,order_item_id),
	foreign key (product_id) references gold.Dim_Products(product_id),
	foreign key (seller_id) references gold.Dim_Sellers(seller_id),
	foreign key (purchase_date) references gold.Dim_Date(date_key)
);
create table gold.Fact_RFM_Segments(
	customer_unique_id varchar(50),
	recency integer,
	frequency integer,
	monetary numeric(10,2),
	r_score integer,
	f_score integer,
	m_score integer,
	cluster_id integer,
	segment_name varchar(50),
	snapshot_date date,
	primary key (customer_unique_id , snapshot_date),
	foreign key (customer_unique_id) references gold.Dim_Customers(customer_unique_id),
	foreign key (snapshot_date) references gold.Dim_Date(date_key)
);