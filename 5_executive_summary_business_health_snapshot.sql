/* ============================================
   EXECUTIVE SUMMARY — BUSINESS HEALTH SNAPSHOT
   Combines: Revenue | Delivery | Customer | Seller
============================================ */


WITH

-- Get last available month
max_month_cte AS (
    SELECT MAX(month) AS max_month 
    FROM monthly_metrics
),

/* ========================
   REVENUE SUMMARY
======================== */
revenue_summary AS (
    SELECT
        SUM(CASE 
            WHEN month >= (SELECT max_month FROM max_month_cte) - INTERVAL '6 months'
            THEN total_revenue ELSE 0 END) AS revenue_last_6m,

        SUM(CASE 
            WHEN month < (SELECT max_month FROM max_month_cte) - INTERVAL '6 months'
            AND month >= (SELECT max_month FROM max_month_cte) - INTERVAL '12 months'
            THEN total_revenue ELSE 0 END) AS revenue_prev_6m,

        ROUND(AVG(aov), 2) AS overall_aov

    FROM monthly_metrics
),

/* ========================
   DELIVERY SUMMARY
======================== */
delivery_summary AS (
    SELECT
        ROUND(
            COUNT(*) FILTER (WHERE delay > 0) * 100.0 / COUNT(*), 2
        ) AS pct_delayed,

        ROUND(AVG(CASE WHEN delay > 0 THEN delay END), 1) AS avg_delay_days,

        ROUND(AVG(review_score), 2) AS overall_avg_rating

    FROM (
        SELECT DISTINCT order_id, delay, review_score
        FROM order_delay_analysis
    ) t
),

/* ========================
   CUSTOMER SUMMARY
======================== */
customer_summary AS (
    SELECT
        COUNT(*) AS total_customers,

        ROUND(
            COUNT(*) FILTER (WHERE frequency > 1) * 100.0 / COUNT(*), 2
        ) AS repeat_customer_pct,

        ROUND(AVG(monetary), 2) AS avg_customer_ltv

    FROM customer_metrics
),

/* ========================
   SELLER THRESHOLDS
======================== */
seller_thresholds AS (
    SELECT
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_revenue) AS revenue_p75,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_delay) AS delay_p75
    FROM seller_metrics
),

/* ========================
   SELLER SUMMARY
======================== */
seller_summary AS (
    SELECT
        COUNT(*) AS total_sellers,

        ROUND(
            COUNT(*) FILTER (
                WHERE avg_rating >= 4 
                AND avg_delay <= st.delay_p75
            ) * 100.0 / COUNT(*), 2
        ) AS pct_healthy_sellers,

        COUNT(*) FILTER (
            WHERE total_revenue >= st.revenue_p75
            AND avg_rating < 3.5
        ) AS high_risk_sellers

    FROM seller_metrics sm
    CROSS JOIN seller_thresholds st
)

-- ========================
-- FINAL SNAPSHOT
-- ========================
SELECT
    ROUND(r.revenue_last_6m, 2) AS revenue_last_6m,
    ROUND(r.revenue_prev_6m, 2) AS revenue_prev_6m,

    ROUND(
        (r.revenue_last_6m - r.revenue_prev_6m) * 100.0 
        / NULLIF(r.revenue_prev_6m, 0), 2
    ) AS revenue_growth_pct,

    r.overall_aov,

    d.pct_delayed AS pct_orders_delayed,
    d.avg_delay_days,
    d.overall_avg_rating,

    c.total_customers,
    c.repeat_customer_pct,
    c.avg_customer_ltv,

    s.total_sellers,
    s.pct_healthy_sellers,
    s.high_risk_sellers

FROM revenue_summary r
CROSS JOIN delivery_summary d
CROSS JOIN customer_summary c
CROSS JOIN seller_summary s;

+--------------------+---------------------+--------------------+-------------+----------------------+----------------+-------------------+------------------+---------------------+-------------------+----------------+-----------------------+--------------------+
| revenue_last_6m    | revenue_prev_6m     | revenue_growth_pct | overall_aov | pct_orders_delayed   | avg_delay_days | overall_avg_rating| total_customers  | repeat_customer_pct | avg_customer_ltv  | total_sellers  | pct_healthy_sellers   | high_risk_sellers  |
+--------------------+---------------------+--------------------+-------------+----------------------+----------------+-------------------+------------------+---------------------+-------------------+----------------+-----------------------+--------------------+
| 6293480.12         | 4448790.58          | 41.46              | 133.03      | 8.00                 | 9.4            | 4.16              | 93358            | 3.00                | 141.62            | 2965           | 56.49                 | 47                 |
+--------------------+---------------------+--------------------+-------------+----------------------+----------------+-------------------+------------------+---------------------+-------------------+----------------+-----------------------+--------------------+

/*Executive Summary

The business demonstrates strong recent growth, with revenue increasing by 41.46% in the last six months compared to the 
previous period, reaching ₹6.29M, indicating successful expansion and demand generation. Average order value remains stable at ₹133, 
suggesting consistent customer spending behavior. Operationally, 8% of orders are delayed, with an average delay of 9.4 days, 
which may be contributing to slightly lower customer satisfaction, reflected in an average rating of 4.16.

From a customer perspective, the platform has a large base of 93K+ customers, but repeat purchase rate is critically low at just 3%,
indicating heavy dependence on new customer acquisition rather than retention. On the supply side, out of 2,965 sellers, only 56.49% 
meet quality benchmarks, while 47 high-revenue sellers exhibit poor customer experience, posing a significant risk to long-term brand trust.*/

Overall, while the business is growing rapidly, it faces key challenges in customer retention, delivery performance, and seller quality consistency. Addressing these areas through improved logistics, better seller management, and targeted retention strategies will be crucial for sustaining long-term growth and profitability.