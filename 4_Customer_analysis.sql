/*========================================
      CUSTOMER ANALYSIS
=========================================*/

-- customer purchase frequency 
SELECT
    CASE 
        WHEN frequency = 1 THEN 'One-time'
        ELSE 'Repeat'
    END AS customer_type,
    COUNT(*) AS customers
FROM customer_metrics
GROUP BY customer_type;

/*The business is heavily dependent on one-time buyers (~97%), indicating extremely poor customer retention.
Despite strong revenue growth, long-term customer loyalty is almost non-existent, making growth unsustainable.
The platform is likely spending heavily on customer acquisition rather than retention, increasing marketing costs.
Low repeat behavior suggests issues in post-purchase experience, product satisfaction, or engagement strategies.
The business should introduce loyalty programs, personalized recommendations, and retention campaigns to convert one-time buyers into repeat customers.*/

-- customer life time value (CLV)
SELECT
    customer_unique_id,
    SUM(monetary) AS lifetime_value
FROM customer_metrics
GROUP BY customer_unique_id
ORDER BY lifetime_value DESC;

-- average orders per customer
SELECT
    AVG(frequency) AS avg_orders_per_customer
FROM customer_metrics;

/*Retention of customers is very low with avg frequency of customer ~ 1.03 which means a customer purchases once and never buys again*/

-- Customer purchase frequency vs rating
WITH customer_reviews AS (
    SELECT
        c.customer_unique_id,
        AVG(r.review_score) AS avg_review
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_reviews_clean r ON o.order_id = r.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    CASE 
        WHEN cm.frequency = 1 THEN 'One-time'
        ELSE 'Repeat'
    END AS customer_type,

    AVG(cr.avg_review) AS avg_rating

FROM customer_metrics cm
JOIN customer_reviews cr 
    ON cm.customer_unique_id = cr.customer_unique_id

GROUP BY customer_type;

/*Repeat customers consistently give higher ratings than one-time customers, indicating better overall satisfaction.
This suggests that customers who have a good first experience are more likely to return, reinforcing the importance of first impressions.
The difference is small but meaningful at scale, especially given the huge volume of one-time users.
Poor initial experiences may be a key reason why ~97% of customers never return.
The business should focus on improving first-order experience (delivery, product quality, support) to increase retention and long-term revenue.*/