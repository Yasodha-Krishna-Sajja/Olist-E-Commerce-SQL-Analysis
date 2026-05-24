/* ============================================
   MONTHLY REVENUE ANALYSIS
============================================ */

CREATE OR REPLACE VIEW monthly_metrics AS
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,

    COUNT(DISTINCT o.order_id) AS total_orders,

    COUNT(DISTINCT c.customer_unique_id) AS total_customers,

    SUM(oi.price) AS total_revenue,

    SUM(oi.price) * 1.0 / COUNT(DISTINCT o.order_id) AS aov

FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY month;

-- Monthly revenue
SELECT *
FROM monthly_metrics
ORDER BY month;

/*1. Revenue shows a strong upward trend throughout 2017, indicating rapid business growth.
2. The highest performance is observed in November 2017, suggesting a seasonal spike.
3. In 2018, revenue stabilizes, indicating a mature and consistent level of business activity.
4. Average order value remains relatively stable across months, showing consistent customer spending behavior.
5. Earlier perceived declines were due to aggregating multiple years, highlighting the importance of correct time-based analysis.*/

--MOM growth
SELECT
    month,
    total_revenue,

    LAG(total_revenue) OVER (ORDER BY month) AS prev_revenue,

    (total_revenue - LAG(total_revenue) OVER (ORDER BY month)) * 100.0
    / LAG(total_revenue) OVER (ORDER BY month) AS mom_growth_pct

FROM monthly_metrics
ORDER BY month;

/*1. The business experienced rapid expansion in 2017, with several months showing strong double-digit MoM growth.
2. Growth during the expansion phase was volatile, indicating typical scaling fluctuations.
3. A significant revenue spike occurred in November 2017, likely driven by seasonal demand such as holiday sales.
4. Post-peak decline in December suggests strong seasonality effects in customer purchasing behavior.
5. In 2018, revenue growth stabilized with smaller fluctuations, indicating the business entered a mature phase.*/

-- What causes revenue growth customer growth or increase in average spend value?
SELECT
    month,

    total_customers,
    (total_customers - LAG(total_customers) OVER (ORDER BY month)) * 100.0
    / LAG(total_customers) OVER (ORDER BY month) AS customer_growth_pct,

    aov,
    (aov - LAG(aov) OVER (ORDER BY month)) * 100.0
    / LAG(aov) OVER (ORDER BY month) AS aov_growth_pct,

    total_revenue,
    (total_revenue - LAG(total_revenue) OVER (ORDER BY month)) * 100.0
    / LAG(total_revenue) OVER (ORDER BY month) AS revenue_growth_pct

FROM monthly_metrics
ORDER BY month;

/*1. Revenue growth is primarily driven by increases in the number of active customers rather than changes in average order value.
2. AOV remains relatively stable with minor fluctuations, indicating limited growth in customer spending behavior.
3. Major revenue spikes, such as in November 2017, are strongly correlated with sharp increases in customer acquisition.
4. Declines in revenue consistently align with drops in customer count, highlighting dependency on new users.
5. In 2018, both customer growth and revenue begin to stabilize, suggesting the business is entering a mature phase with slowing expansion.*/

-- Retained customers per month
WITH customer_month AS (
    SELECT
        customer_unique_id,
        DATE_TRUNC('month', order_purchase_timestamp) AS month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id, month
)

SELECT
    c1.month,
    COUNT(DISTINCT c1.customer_unique_id) AS total_customers,
    COUNT(DISTINCT c2.customer_unique_id) AS retained_customers,
	COUNT(DISTINCT c2.customer_unique_id) * 100.0 
    / COUNT(DISTINCT c1.customer_unique_id) AS retention_rate

FROM customer_month c1

LEFT JOIN customer_month c2
    ON c1.customer_unique_id = c2.customer_unique_id
   AND c2.month = c1.month + INTERVAL '1 month'

GROUP BY c1.month
ORDER BY c1.month;

CREATE OR REPLACE VIEW customer_metrics AS
SELECT
    c.customer_unique_id,

    MAX(o.order_purchase_timestamp) AS last_purchase,

    COUNT(DISTINCT o.order_id) AS frequency,

    SUM(oi.price) AS monetary

FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY c.customer_unique_id;


SELECT *
FROM customer_metrics;

/*1. Month-to-month retention is extremely low, with less than 1% of customers returning in the immediate next month.
2. This indicates that most customers make a one-time purchase rather than engaging in repeat buying behavior.
3. The business heavily relies on acquiring new customers each month to sustain revenue growth.
4. There is a clear lack of short-term customer loyalty and engagement on the platform.
5. Improving retention through loyalty programs, personalized marketing, and post-purchase engagement should be a key strategic focus.*/

-- segmentation of customers based on frequency and monetory
WITH scored AS (
    SELECT
        *,
        NTILE(3) OVER (ORDER BY frequency) AS f_score,
        NTILE(3) OVER (ORDER BY monetary) AS m_score
    FROM customer_metrics
)

SELECT
    CASE
        WHEN f_score = 3 AND m_score = 3 THEN 'High Value'
        WHEN f_score >= 2 AND m_score >= 2 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS segment,

    COUNT(*) AS customers,
    AVG(monetary) AS avg_spend

FROM scored
GROUP BY segment
ORDER BY customers DESC;

/*1. High-value customers spend ~8x more than low-value customers (₹306 vs ₹38).
2. Medium-value customers show moderate engagement but significantly lower spend than high-value users.
3. Revenue is likely driven disproportionately by the high-value segment despite equal customer distribution.
4. Low-value customers contribute minimal revenue and are likely one-time or low-engagement buyers.
5. There is a strong opportunity to convert medium-value customers into high-value customers to increase revenue.*/

-- How much revenue are we losing each month due to unavailable or canceled orders
WITH revenue_data AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,

        SUM(CASE 
            WHEN o.order_status = 'delivered' THEN oi.price 
            ELSE 0 END) AS realized_revenue,

        SUM(CASE 
            WHEN o.order_status IN ('canceled','unavailable') THEN oi.price 
            ELSE 0 END) AS lost_revenue

    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
	WHERE o.order_status IN ('delivered','canceled','unavailable')
    GROUP BY month
)

SELECT
    month,
    realized_revenue,
    lost_revenue,
    
    (lost_revenue * 100.0 / NULLIF(realized_revenue + lost_revenue,0)) AS loss_percentage

FROM revenue_data
ORDER BY month

--Analyzed monthly revenue leakage and found that less than 1% of revenue is lost due to cancellations, 
--indicating strong operational efficiency, while identifying specific months with elevated losses for targeted improvements.