
CREATE TABLE customers(
	customer_id VARCHAR(50) PRIMARY KEY,
	customer_unique_id VARCHAR(50),
	customer_zip_code_prefix INT,
	customer_city VARCHAR(50),
	customer_state CHAR(2)
);

CREATE TABLE orders(
	order_id VARCHAR(50) PRIMARY KEY,
	customer_id VARCHAR(50),
	order_status VARCHAR(20),
	order_purchase_timestamp TIMESTAMP,
	order_approved_at TIMESTAMP,
	order_delivered_carrier_date TIMESTAMP,
	order_delivered_customer_date TIMESTAMP,
	order_estimated_delivery_date TIMESTAMP,

	FOREIGN KEY(customer_id)
	REFERENCES customers(customer_id)
);

CREATE TABLE products(
	product_id VARCHAR(50) PRIMARY KEY,
	product_category_name VARCHAR(100),
	product_name_length INT,
	product_description_length INT,
	product_photos_qty INT,
	product_weight_g INT,
	product_length_cm INT,
	product_height_cm INT,
	product_width_cm INT
);

CREATE TABLE sellers(
	seller_id VARCHAR(50) PRIMARY KEY,
	seller_zip_code_prefix INT,
	seller_city VARCHAR(100),
	seller_state CHAR(2)
);

CREATE TABLE product_category_name_translation(
	product_category_name VARCHAR(100) PRIMARY KEY,
	product_category_name_english VARCHAR(100)
);

CREATE TABLE geolocation(
	geolocation_zip_code_prefix INT,
	geolocation_lat NUMERIC(5,8),
	geolocation_lng NUMERIC(5,8),
	geolocation_city VARCHAR(100),
	geolocation_state CHAR(2)
);

CREATE TABLE order_items(
	order_id VARCHAR(50),
	order_item_id INT,
	product_id VARCHAR(50),
	seller_id VARCHAR(50),
	shipping_limit_date TIMESTAMP,
	price NUMERIC(10,5),
	freight_value NUMERIC(10,5),

	PRIMARY KEY(order_id,order_item_id),

	FOREIGN KEY(order_id)
	REFERENCES orders(order_id),
	
	FOREIGN KEY(product_id)
	REFERENCES products(product_id),

	FOREIGN KEY(seller_id)
	REFERENCES sellers(seller_id)
);

CREATE TABLE order_payments(
	order_id VARCHAR(50),
	payment_sequential INT,
	payment_type VARCHAR(20),
	payment_installments INT,
	payment_value NUMERIC(10,5),

	PRIMARY KEY ( order_id, payment_sequential),

	FOREIGN KEY(order_id)
	REFERENCES orders(order_id)
);

CREATE TABLE order_reviews(
	review_id VARCHAR(50) PRIMARY KEY,
	order_id VARCHAR(50),
	review_score INT,
	review_comment_title TEXT,
	review_comment_message TEXT,
	review_creation_date TIMESTAMP,
	review_answer_timestamp TIMESTAMP,

	FOREIGN KEY(order_id)
	REFERENCES orders(order_id)
);












