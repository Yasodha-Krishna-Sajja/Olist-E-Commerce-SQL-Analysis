/*========================================
      PRODUCT ANALYSIS
=========================================*/

-- TOTAL REVENUE
SELECT 
	SUM(oi.price) AS total_revenue
FROM order_items oi
JOIN orders o ON oi.order_id=o.order_id
WHERE o.order_status='delivered'

-- REVENUE DISTRIBUTION AMONG PRODUCT CATEGORIES

SELECT
	pn.product_category_name_english,
	COUNT(DISTINCT oi.order_id) AS total_orders,
	SUM(oi.price) AS product_revenue,
	SUM(oi.price)*100.0/SUM(SUM(oi.price)) OVER() AS revenue_pct
FROM
	order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id=o.order_id
JOIN product_category_name_translation pn ON p.product_category_name = pn.product_category_name
WHERE order_status='delivered'
GROUP BY product_category_name_english
ORDER BY product_revenue DESC

/*1. Revenue is highly concentrated, with top 5 categories (Health & Beauty, Watches & Gifts, Bed/Bath/Table, Sports & Leisure, Computers Accessories) contributing ~40% of total revenue.
2. A small number of categories dominate business performance, indicating strong dependency on a limited product mix.
3. Mid-tier categories (5–10 range) contribute steadily, forming the backbone of consistent revenue.
4. A long tail of low-performing categories contributes less than 1% each, adding minimal impact to overall revenue.
5. This distribution follows a Pareto-like pattern, where a minority of categories drive the majority of revenue.*/

-- CATEGORY WISE AOV
SELECT
    pn.product_category_name_english,
    SUM(oi.price) * 1.0 / COUNT(DISTINCT oi.order_id) AS avg_order_value
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
JOIN product_category_name_translation pn ON p.product_category_name = pn.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY pn.product_category_name_english
ORDER BY avg_order_value DESC;

/*1. Categories like Computers, Small Appliances, and Home Appliances have the highest AOV, indicating high-ticket purchases.
2. High AOV categories contribute significant revenue per order but may have lower order volumes.
3. Categories such as Flowers, Food, and Home Comfort have very low AOV, indicating frequent but low-value purchases.
4. Mid-range categories (Health & Beauty, Sports, Toys) balance both volume and value, making them stable revenue drivers.
5. The business has a mix of high-value and low-value categories, suggesting diverse customer purchasing behavior.*/

--WHICH PRODUCT CATEGORIES ARE WE LOSING
WITH loss_category AS(
	SELECT
		pn.product_category_name_english AS product_category_name,
		COUNT(DISTINCT oi.order_id) AS lost_orders,
		SUM(oi.price) AS loss_revenue
	FROM
		order_items oi
	JOIN products p ON oi.product_id=p.product_id
	JOIN orders o ON oi.order_id=o.order_id
	JOIN product_category_name_translation pn ON p.product_category_name = pn.product_category_name
	WHERE o.order_status IN ('canceled','unavailable')
	GROUP BY product_category_name_english
	ORDER BY loss_revenue DESC
)
SELECT *FROM loss_category
/*1. Revenue loss is concentrated in a few categories, with Cool Stuff, Sports & Leisure, and Computers Accessories leading in total loss.
2. High-loss categories are also among high-revenue categories, amplifying their business impact.
3. Some categories show high loss despite relatively low order counts, indicating high-value order cancellations.
4. Categories like Musical Instruments and Home Appliances 2 have fewer lost orders but significant revenue loss, suggesting high AOV risk.
5. Long-tail categories contribute minimal loss, indicating that operational issues are concentrated in specific product segments.*/


-- CATEGORY LEVEL FULL ANALYSIS
WITH category_metrics AS (
    SELECT
        pn.product_category_name_english AS product_category_name,

        SUM(oi.price) AS total_revenue,

        AVG(od.delay) AS avg_delay,

        AVG(od.review_score) AS avg_review

    FROM order_items oi
    JOIN orders o 
        ON oi.order_id = o.order_id
    JOIN products p 
        ON oi.product_id = p.product_id
    JOIN product_category_name_translation pn 
        ON p.product_category_name = pn.product_category_name
    JOIN order_delay_analysis od 
        ON oi.order_id = od.order_id

    WHERE o.order_status = 'delivered'
      AND od.delay >= 0

    GROUP BY pn.product_category_name_english
),

loss_category AS (
    SELECT
        pn.product_category_name_english AS product_category_name,

        COUNT(DISTINCT oi.order_id) AS lost_orders,

        SUM(oi.price) AS loss_revenue

    FROM order_items oi
    JOIN products p 
        ON oi.product_id = p.product_id
    JOIN orders o 
        ON oi.order_id = o.order_id
    JOIN product_category_name_translation pn 
        ON p.product_category_name = pn.product_category_name

    WHERE o.order_status IN ('canceled','unavailable')

    GROUP BY pn.product_category_name_english
)

SELECT
    c.product_category_name,
    c.total_revenue,
    c.avg_delay,
    c.avg_review,
    COALESCE(l.loss_revenue, 0) AS loss_revenue,
    COALESCE(l.lost_orders, 0) AS lost_orders

FROM category_metrics c
LEFT JOIN loss_category l
    ON c.product_category_name = l.product_category_name

ORDER BY loss_revenue DESC;
/*High loss categories like cool_stuff, sports_leisure, computers_accessories combine high delay (~9–10 days) and low ratings (~2.5), indicating logistics issues → optimize delivery partners & inventory placement.
Categories with high delay but low loss (e.g., home_appliances_2, air_conditioning) show poor experience but low scale → fix early before they grow into major problems.
Low review scores (~2–2.7) across most loss-heavy categories suggest customer dissatisfaction is a key driver of cancellations → improve product quality, descriptions, and seller vetting.
Some categories (e.g., electronics, small_appliances) have high loss per order despite low order count → flag high-value orders for stricter fulfillment monitoring.
Overall pattern shows delivery delay + poor experience → cancellations → revenue loss, so focusing on faster delivery SLAs, better seller quality, and proactive communication will directly reduce losses.*/


