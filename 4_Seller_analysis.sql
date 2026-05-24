/*========================================
      SELLER ANALYSIS
=========================================*/
-- seller_metrics view 
CREATE OR REPLACE VIEW seller_metrics AS
WITH order_level AS (
    SELECT
        order_id,
        AVG(delay) AS delay,
        AVG(review_score) AS review_score
    FROM order_delay_analysis
    GROUP BY order_id
)

SELECT
    oi.seller_id,

    COUNT(DISTINCT oi.order_id) AS total_orders,

    SUM(oi.price) AS total_revenue,

    SUM(oi.price) * 1.0 
        / COUNT(DISTINCT oi.order_id) AS aov,

    AVG(ol.delay) AS avg_delay,

    AVG(ol.review_score) AS avg_rating

FROM order_items oi
JOIN orders o 
    ON oi.order_id = o.order_id
JOIN order_level ol 
    ON oi.order_id = ol.order_id

WHERE o.order_status = 'delivered'

GROUP BY oi.seller_id;

SELECT *FROM seller_metrics

-- Top 10 sellers by revenue
SELECT *
FROM seller_metrics
ORDER BY total_revenue DESC
LIMIT 10;

-- Worst sellers with less rating and high delay
SELECT *
FROM seller_metrics
WHERE avg_rating < 3
  AND avg_delay > 5
ORDER BY avg_delay DESC;

--high revenue but poor experience sellers
SELECT *
FROM seller_metrics
WHERE total_revenue > (
    SELECT AVG(total_revenue) FROM seller_metrics
)
AND avg_rating < 3.5
ORDER BY total_revenue DESC;

/*Several sellers generate high revenue despite low ratings (<3.5), so prioritize auditing these sellers and fix product quality or listing issues to protect platform trust.
Since most low-rated sellers still deliver early, the problem is not logistics but product/service gaps—introduce stricter quality checks and clearer product descriptions.
Extremely low-rated sellers (≈1.4–2.8) with high AOV indicate severe dissatisfaction, so apply penalties or minimum rating thresholds for continued selling.
High-volume low-rating sellers pose the biggest risk at scale, so reduce their visibility while promoting better-performing sellers.
Shift demand toward high-rating sellers through recommendations and incentives to improve overall customer experience and long-term retention.*/

--seller segmentation
WITH percentiles AS (
    SELECT
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_revenue) AS p75,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_revenue) AS p25
    FROM seller_metrics
),

segmented AS (
    SELECT
        s.*,
        CASE
            WHEN s.total_revenue >= p.p75 THEN 'Top Sellers'
            WHEN s.total_revenue >= p.p25 THEN 'Mid Sellers'
            ELSE 'Low Sellers'
        END AS seller_segment
    FROM seller_metrics s
    CROSS JOIN percentiles p
)

SELECT
    seller_segment,
    COUNT(*) AS sellers,
    AVG(total_revenue) AS avg_revenue,
    AVG(avg_rating) AS avg_rating
FROM segmented
GROUP BY seller_segment
ORDER BY seller_segment;

/*Top sellers generate disproportionately high revenue (~15K avg) but have slightly lower ratings, so prioritize quality audits to prevent long-term brand damage.
Mid sellers show balanced revenue and the best ratings, making them ideal candidates for promotion and scaling through incentives.
Low sellers contribute minimal revenue despite decent ratings, so provide onboarding support or tools to help them grow performance.
The platform heavily depends on a small group of top sellers, so diversify revenue by uplifting mid-tier sellers to reduce risk.
Improve overall marketplace quality by rewarding high-rating sellers with visibility and gradually filtering out consistently low-performing ones*/

