/* ============================================
   BUSINESS PROBLEM : DELIVERY PERFORMANCE
============================================ */

-- Percentage of delayed orders
SELECT
	ROUND(COUNT(*) FILTER(
		WHERE order_estimated_delivery_date < order_delivered_customer_date
	)*100.0	
	/ COUNT(*),2) AS percent_delayed_orders
FROM
orders;

--Average delivery delay for an order
SELECT
	AVG(order_delivered_customer_date-order_estimated_delivery_date)
FROM
	orders
WHERE order_delivered_customer_date IS NOT NULL AND
      order_estimated_delivery_date < order_delivered_customer_date;

-- Delay Vs Review Score
SELECT
	MIN(order_delivered_customer_date-order_estimated_delivery_date),
	MAX(order_delivered_customer_date-order_estimated_delivery_date),
	AVG(order_delivered_customer_date-order_estimated_delivery_date)
FROM
	orders
WHERE
	order_delivered_customer_date IS NOT NULL AND
    order_estimated_delivery_date < order_delivered_customer_date;


--creating order_delay_analysis view

CREATE VIEW order_delay_analysis AS
SELECT
	o.order_id,
	EXTRACT(EPOCH FROM o.order_delivered_customer_date-o.order_estimated_delivery_date)/86400 AS delay,
	oi.product_id,
	p.product_category_name,
	oi.seller_id,
	r.review_id,
	r.review_score
FROM
	orders o
JOIN order_items oi ON o.order_id=oi.order_id
JOIN products p ON oi.product_id=p.product_id
JOIN order_reviews_clean r ON o.order_id=r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL;

-- delay vs review_score
WITH order_level AS (
    SELECT DISTINCT
        order_id,
        delay,
        review_score
    FROM order_delay_analysis
)

SELECT
    CASE 
        WHEN delay <= 0 THEN 'on-time'
        WHEN delay <= 5 THEN '0-5 days'
        WHEN delay <= 15 THEN '6-15 days'
        WHEN delay <= 30 THEN '16-30 days'
        WHEN delay <= 60 THEN '31-60 days'
        WHEN delay <= 100 THEN '61-100 days'
        ELSE '100+ days (Extreme)'
    END AS delay_bucket,

    COUNT(*) AS total_orders,
    AVG(review_score) AS avg_review_score

FROM order_level

WHERE delay >= 0

GROUP BY delay_bucket
ORDER BY MIN(delay);

--alternative method(optional)
WITH delay_cte AS(
	SELECT *,EXTRACT(EPOCH FROM order_delivered_customer_date-order_estimated_delivery_date)/86400 AS delay
	FROM orders
	WHERE order_delivered_customer_date IS NOT NULL AND
          order_estimated_delivery_date < order_delivered_customer_date
)
SELECT
	CASE 
		WHEN delay <=0 THEN 'on-time'
		WHEN delay <=5 THEN '0-5 days'
		WHEN delay <=15 THEN '6-15 days'
		WHEN delay <=30 THEN '16-30 days'
		WHEN delay <=60 THEN '31-60 days'
		WHEN delay <=100 THEN '61-100 days'
		ELSE '100+ days (Extreme)'
	END AS delay_bucket,
	COUNT(*) AS total_orders,
	AVG(o.review_score)
FROM
	delay_cte d
JOIN order_reviews_clean o ON d.order_id=o.order_id
WHERE o.review_score IS NOT NULL
GROUP BY delay_bucket
ORDER BY MIN(delay);

/*Customer satisfaction drops dramatically when delivery delays exceed 5 days,
with the lowest satisfaction observed between 6–30 days.

Beyond 30 days, the number of orders decreases significantly,
making trends less reliable and likely influenced by edge cases.

Suggestion
The business should prioritize keeping delivery delays within 5 days,
as customer satisfaction drops sharply beyond this threshold.

Efforts to reduce delays in the 6–30 day range will have the highest impact on customer experience.*/

-- WHICH PRODUCT CATEGORIES CAUSING POOR Delay and ratings
SELECT *FROM order_delay_analysis

WITH order_level AS(
	SELECT DISTINCT
	order_id,
	product_category_name,
	delay,
	review_score
	FROM
	order_delay_analysis
)
SELECT
	o.product_category_name,
	p.product_category_name_english,
	ROUND(AVG(o.delay),2) AS avg_delay,
	ROUND(AVG(o.review_score),2) AS avg_review_score
FROM order_level o
JOIN product_category_name_translation p ON o.product_category_name=p.product_category_name
WHERE o.delay>=0 AND o.review_score IS NOT NULL
GROUP BY o.product_category_name,p.product_category_name_english
ORDER BY avg_delay DESC,avg_review_score ASC

/*The analysis reveals that product categories involving bulky or complex logistics,
such as furniture and appliances, experience significantly higher delivery delays
and lower customer satisfaction.

In contrast, some categories maintain relatively stable satisfaction despite delays,
indicating that customer expectations vary across product types.

This suggests that targeted logistics improvements and category-specific strategies
are more effective than a one-size-fits-all approach.*/

-- Which sellers causing delys in high delay categories
WITH filtered_data AS (
    SELECT
        order_id,
        seller_id,
        product_category_name,
        delay,
        review_score
    FROM order_delay_analysis
    WHERE delay >= 0
      AND review_score IS NOT NULL
      AND product_category_name IN (
        'eletrodomesticos_2',
		'moveis_colchao_e_estofado',
		'sinalizacao_e_seguranca',
		'artigos_de_natal',
		'casa_conforto'
      )
),

seller_performance AS (
    SELECT
        seller_id,
        product_category_name,
        COUNT(DISTINCT order_id) AS total_orders,
        AVG(delay) AS avg_delay,
        AVG(review_score) AS avg_review
    FROM filtered_data
    GROUP BY seller_id, product_category_name
)

SELECT *
FROM seller_performance  -- avoid noise
WHERE total_orders >=2
ORDER BY product_category_name ASC,
		total_orders DESC,
		avg_delay DESC,
		avg_review ASC

/*
1. A small group of sellers in high-delay categories drives most delivery delays and low customer satisfaction.
2. High-volume sellers with moderate delays have a greater overall impact than low-volume extreme cases.
3. Delivery delays strongly affect reviews, but some low ratings occur even with acceptable delivery times, indicating product/service issues.
4. Significant performance variation within the same category shows that delays are seller-specific, not just category-driven.
5. Focus should be on monitoring underperforming sellers, improving logistics for bulky products, and enforcing quality and delivery standards.*/


