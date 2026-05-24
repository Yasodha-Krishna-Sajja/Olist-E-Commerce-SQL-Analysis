/*========================================================
    OLIST ECOMMERCE DATASET
    DATA CLEANING & VALIDATION SCRIPT
==========================================================*/


/*========================================================
    1. PRODUCTS TABLE VALIDATION
==========================================================*/

-- Rows where category is missing but product metadata exists
SELECT *
FROM products
WHERE product_category_name IS NULL
  AND product_name_length IS NOT NULL
  AND product_description_length IS NOT NULL
  AND product_photos_qty IS NOT NULL;

-- All rows with missing product category
SELECT *
FROM products
WHERE product_category_name IS NULL;

-- Missing product dimensions
SELECT *
FROM products
WHERE product_width_cm IS NULL;

-- Invalid logistics measurements
SELECT *
FROM products
WHERE product_weight_g <= 0
   OR product_length_cm <= 0
   OR product_height_cm <= 0
   OR product_width_cm <= 0;

--  inspect suspicious zero-weight products
SELECT *
FROM products
WHERE product_weight_g = 0;


/*========================================================
    2. SELLERS TABLE VALIDATION
==========================================================*/

-- Missing seller state values
SELECT *
FROM sellers
WHERE seller_state IS NULL;


/*========================================================
    3. CUSTOMERS TABLE VALIDATION
==========================================================*/


--Check for NULL Values
SELECT
    COUNT(*) - COUNT(customer_id) AS null_customer_id,
    COUNT(*) - COUNT(customer_unique_id) AS null_customer_unique_id,
    COUNT(*) - COUNT(customer_zip_code_prefix) AS null_zip_code,
    COUNT(*) - COUNT(customer_city) AS null_city,
    COUNT(*) - COUNT(customer_state) AS null_state
FROM customers;

-- Duplicate customer IDs(customers placing multiple orders)
SELECT
    customer_unique_id,
    COUNT(*) AS total_orders
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

--Validate State Codes
SELECT DISTINCT customer_state
FROM customers
ORDER BY customer_state;

--checking missing or invalid city names
SELECT *
FROM customers
WHERE customer_city IS NULL
   OR TRIM(customer_city) = '';

--checking invalid zip prefixes
SELECT *
FROM customers
WHERE customer_zip_code_prefix <= 0;

--customer distribut
/*========================================================
    4. GEOLOCATION TABLE VALIDATION
==========================================================*/

-- Duplicate zip code prefixes
SELECT
    geolocation_zip_code_prefix,
    COUNT(*) AS duplicate_count
FROM geolocation
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(*) > 1;

-- Example inspection of duplicate zip code
SELECT *
FROM geolocation
WHERE geolocation_zip_code_prefix = 74710;

-- Duplicate latitude/longitude coordinate pairs
SELECT
    geolocation_lat,
    geolocation_lng,
    COUNT(*) AS duplicate_count
FROM geolocation
GROUP BY geolocation_lat, geolocation_lng
HAVING COUNT(*) > 1;


/*========================================================
    5. ORDERS TABLE VALIDATION
==========================================================*/

-- Distinct order statuses
SELECT DISTINCT order_status
FROM orders;

-- Approval timestamp before purchase timestamp
SELECT
    order_purchase_timestamp,
    order_approved_at
FROM orders
WHERE order_approved_at < order_purchase_timestamp;

-- Carrier timestamp before approval timestamp
SELECT
    order_approved_at,
    order_delivered_carrier_date,
    order_approved_at - order_delivered_carrier_date AS diff
FROM orders
WHERE order_delivered_carrier_date < order_approved_at
ORDER BY diff DESC;

-- Large timestamp inconsistencies (>30 days)
SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    order_approved_at - order_delivered_carrier_date AS diff
FROM orders
WHERE order_approved_at - order_delivered_carrier_date >
      INTERVAL '30 days';

-- Carrier delivery before purchase timestamp
SELECT
    order_purchase_timestamp,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_purchase_timestamp - order_delivered_carrier_date AS diff
FROM orders
WHERE order_delivered_carrier_date < order_purchase_timestamp
ORDER BY diff DESC;

-- Customer delivery before approval timestamp
SELECT
    order_approved_at,
    order_delivered_customer_date,
    order_approved_at - order_delivered_customer_date AS diff
FROM orders
WHERE order_delivered_customer_date < order_approved_at
ORDER BY diff DESC;

-- Customer delivery before purchase timestamp
SELECT
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_purchase_timestamp - order_delivered_customer_date AS diff
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp
ORDER BY diff DESC;

-- Customer delivery before carrier delivery
SELECT
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_delivered_customer_date - order_delivered_carrier_date AS diff
FROM orders
WHERE order_delivered_customer_date < order_delivered_carrier_date
ORDER BY diff DESC;


/*========================================================
    6. ORDER_ITEMS TABLE VALIDATION
==========================================================*/

-- Unique orders in order_items table
SELECT COUNT(DISTINCT order_id)
FROM order_items;

-- Total orders in orders table
SELECT COUNT(order_id)
FROM orders;

-- Orders present in orders table but absent in order_items
WITH item_orders AS (
    SELECT DISTINCT order_id
    FROM order_items
)

SELECT *
FROM orders o
LEFT JOIN item_orders io
    ON o.order_id = io.order_id
WHERE io.order_id IS NULL;

-- Negative freight values
SELECT *
FROM order_items
WHERE freight_value < 0;

-- Exact duplicate order item structures
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    COUNT(*) AS duplicate_count
FROM order_items
GROUP BY
    order_id,
    order_item_id,
    product_id,
    seller_id
HAVING COUNT(*) > 1;

-- Freight cost greater than product price
SELECT *,
       freight_value - price AS diff
FROM order_items
WHERE freight_value > price
ORDER BY diff DESC;


/*========================================================
    7. ORDER_PAYMENTS TABLE VALIDATION
==========================================================*/

-- Missing payment values
SELECT *
FROM order_payments
WHERE payment_value IS NULL;

-- Payment type distribution
SELECT
    payment_type,
    COUNT(*) AS payment_count
FROM order_payments
GROUP BY payment_type
ORDER BY payment_count DESC;

-- Orders present in payments but absent in order_items
WITH payment_orders AS (
    SELECT DISTINCT order_id
    FROM order_payments
)

SELECT *
FROM payment_orders po
LEFT JOIN order_items oi
    ON po.order_id = oi.order_id
WHERE oi.order_id IS NULL;

-- Validate whether missing orders match previous missing orders
WITH orders_missing_items AS (
    SELECT DISTINCT o.order_id
    FROM orders o
    LEFT JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE oi.order_id IS NULL
),

payments_missing_items AS (
    SELECT DISTINCT op.order_id
    FROM order_payments op
    LEFT JOIN order_items oi
        ON op.order_id = oi.order_id
    WHERE oi.order_id IS NULL
)

SELECT order_id
FROM orders_missing_items

EXCEPT

SELECT order_id
FROM payments_missing_items;


/*========================================================
    8. ORDER_REVIEWS TABLE VALIDATION
==========================================================*/

-- Duplicate review IDs across multiple orders
SELECT DISTINCT review_id
FROM order_reviews
WHERE review_id IN (
    SELECT review_id
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
ORDER BY review_id;

-- Invalid review scores
SELECT *
FROM order_reviews
WHERE review_score < 0
   OR review_score > 5;

-- Optional: inspect review_id duplication behavior
SELECT *
FROM order_reviews
WHERE review_id IN (
    SELECT review_id
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
ORDER BY review_id;

-- ========================================================
-- CLEANED DATASET CREATION
-- ========================================================

-- Deduplicated order reviews (1 review per order
CREATE VIEW order_reviews_clean AS
SELECT DISTINCT ON (order_id) *
FROM order_reviews
ORDER BY order_id, review_answer_timestamp DESC;

SELECT *FROM order_reviews_clean;