--- EXPLORATORY DATA ANALYSIS 

--- Total number of unique customers
SELECT COUNT(DISTINCT customer_unique_id)
FROM customers; 

-- Customer Distribution by states
SELECT customer_state,
	   COUNT(DISTINCT customer_unique_id) AS customer_count
FROM
	customers
GROUP BY customer_state
ORDER BY customer_count DESC;  -- SP has maximum number of customers

-- Customer Distribution by City
SELECT customer_city,
	   COUNT(DISTINCT customer_unique_id) AS customer_count
FROM
	customers
GROUP BY customer_city
ORDER BY customer_count DESC; -- sao paulo has maximum customers

-- Total number of orders
SELECT COUNT(order_id) AS total_orders
FROM orders;

-- Top 10 customers by number of orders placed
SELECT
	c.customer_unique_id,
	COUNT(o.order_id) AS orders_count
FROM
	orders o
JOIN customers c ON o.customer_id=c.customer_id
GROUP BY
	customer_unique_id
ORDER BY
	orders_count DESC
LIMIT 10;

-- order_status distribution across orders
SELECT
	order_status,
	COUNT(*) as distribution_cnt
FROM
	orders
GROUP BY
	order_status
ORDER BY
	distribution_cnt DESC;

-- simplified view
SELECT
    CASE 
        WHEN order_status = 'delivered' THEN 'Completed'
        WHEN order_status IN ('shipped','processing','approved','created','invoiced') THEN 'In Progress'
        WHEN order_status IN ('canceled','unavailable') THEN 'Failed'
    END AS order_group,
    COUNT(*) 
FROM orders
GROUP BY order_group;

-- Average delievry time for an order
SELECT
    AVG(order_delivered_customer_date - order_purchase_timestamp) AS avg_delivery_time
FROM orders
WHERE order_delivered_customer_date IS NOT NULL;-- 12 days is the average delivery time for an order

--Average delivery delay for an order
SELECT
	AVG(order_delivered_customer_date-order_estimated_delivery_date)
FROM
	orders
WHERE order_delivered_customer_date IS NOT NULL AND
      order_estimated_delivery_date < order_delivered_customer_date;

SELECT *FROM orders LIMIT 5;

-- Percentage of delayed orders
SELECT
	COUNT(*) FILTER(
		WHERE order_estimated_delivery_date < order_delivered_customer_date
	)*100.0	
	/ COUNT(*) AS percent_delayed_orders
FROM
orders;

SELECT *FROM orders WHERE order_delivered_customer_date is NULL;
SELECT *FROM orders WHERE order_purchase_timestamp is NULL;

--Top 5 most purchased product categories

SELECT
	p.product_category_name,
	pc.product_category_name_english,
	COUNT(*) AS purchase_count
FROM
	order_items o
JOIN products p ON o.product_id=p.product_id
JOIN product_category_name_translation pc ON p.product_category_name=pc.product_category_name
GROUP BY p.product_category_name,product_category_name_english
ORDER BY purchase_count DESC
LIMIT 10;

-- Top 10 sellers
SELECT
	seller_id,
	COUNT(*) sales_count
FROM
	order_items
GROUP BY seller_id
ORDER BY sales_count DESC
LIMIT 10;


-- multiple order_ids with same review score
WITH cte AS(
	SELECT
		order_id,
		COUNT(*)
	FROM
		order_reviews
	GROUP BY order_id
	HAVING COUNT(*)>1
)
SELECT *FROM order_reviews o JOIN cte ON o.order_id=cte.order_id
ORDER BY cte.order_id;

--prove that multiple reviews for the same order are from the same customer
WITH cte AS(
	SELECT
		order_id,
		COUNT(*)
	FROM
		order_reviews
	GROUP BY order_id
	HAVING COUNT(*)>1
)
SELECT ore.review_id,ore.order_id,o.customer_id,ore.review_score,ore.review_comment_message FROM order_reviews ore JOIN cte ON ore.order_id=cte.order_id JOIN orders o ON ore.order_id=o.order_id
ORDER BY cte.order_id; -- found that multiple entries of same order_id in order_reviews corresponds to same customer so created 
					   -- a view that keeps the latest review for the order removing multiple review entries for same order

-- Most used payment type
SELECT
	payment_type,
	COUNT(*) AS use_count
FROM
	order_payments
GROUP BY payment_type
ORDER BY use_count DESC
LIMIT 1;

-- what is the average transaction amount for each payment type

SELECT
	payment_type,
	ROUND(AVG(payment_value),2) AS avg_transaction
FROM
	order_payments
GROUP BY payment_type
ORDER BY avg_transaction DESC;