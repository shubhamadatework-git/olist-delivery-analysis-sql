/* ==========================================================
   Project : Olist E-Commerce: Delivery Performance & Customer Satisfaction
   File    : 03_analysis.sql (business questions Q1 to Q10)
   Author  : Shubham Adate
   Tool    : MySQL 8.0

   Conventions used in every query:
   - Delivery analysis uses delivered orders only
     (order_status = 'delivered' and a non-null delivery date).
   - An order is LATE when DATEDIFF(delivered, estimated) > 0,
     i.e. it arrived on a later calendar day than estimated.
   - Reviews are averaged per order first, because 547 orders
     have more than one review.
   - Empty category names are shown as 'unknown'.
   ========================================================== */

USE olist_analysis;


-- ----------------------------------------------------------
-- Q1. What is the monthly revenue and order count trend?
-- ----------------------------------------------------------
SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
       COUNT(DISTINCT o.order_id)                       AS total_orders,
       ROUND(SUM(oi.price), 2)                          AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;
-- Insight: Orders were almost nonexistent until late 2016 (Sep 2016 has a single
-- order), then grew steadily through 2017 and peaked in Nov 2017 with 7,289 orders
-- and about R$988K in revenue. After that it levelled off. 2018 months sit between
-- roughly R$825K and R$978K, so growth stalled around early 2018 instead of
-- continuing.


-- ----------------------------------------------------------
-- Q2. Which product categories generate the most revenue?
-- ----------------------------------------------------------
SELECT COALESCE(t.product_category_name_english,
                NULLIF(p.product_category_name, ''), 'unknown') AS category,
       COUNT(DISTINCT oi.order_id)                          AS orders,
       ROUND(SUM(oi.price), 2)                              AS revenue,
       ROUND(100 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 2) AS pct_of_revenue
FROM order_items oi
JOIN orders o   ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation t
       ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;
-- Insight: Revenue is spread across many categories, not owned by one. health_beauty
-- leads with R$1.23M (9.3%), then watches_gifts (8.8%) and bed_bath_table (7.7%).
-- The top 10 together make up about 62% of revenue. watches_gifts stood out to me:
-- it has far fewer orders than bed_bath_table (5,495 vs 9,272) but earns more, so
-- each order is worth roughly twice as much (about R$212 vs R$110).


-- ----------------------------------------------------------
-- Q3. What share of delivered orders arrived late?
-- ----------------------------------------------------------
SELECT COUNT(*) AS delivered_orders,
       SUM(CASE WHEN DATEDIFF(order_delivered_customer_date,
                              order_estimated_delivery_date) > 0
                THEN 1 ELSE 0 END) AS late_orders,
       ROUND(100 * SUM(CASE WHEN DATEDIFF(order_delivered_customer_date,
                                          order_estimated_delivery_date) > 0
                            THEN 1 ELSE 0 END) / COUNT(*), 2) AS late_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;
-- Insight: Out of 96,470 delivered orders, 6,534 arrived after the estimated date,
-- which is 6.77%. Most orders are on time, so lateness is a minority problem, but
-- it still means about 1 in 15 customers waited longer than promised.


-- ----------------------------------------------------------
-- Q4. How does the average review score differ between
--     on-time and late orders?
-- ----------------------------------------------------------
WITH review_per_order AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
)
SELECT CASE WHEN DATEDIFF(o.order_delivered_customer_date,
                          o.order_estimated_delivery_date) > 0
            THEN 'Late' ELSE 'On time' END AS delivery_status,
       COUNT(*)                            AS orders,
       ROUND(AVG(r.review_score), 2)       AS avg_review_score
FROM orders o
JOIN review_per_order r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;
-- Insight: This is the main finding of the project. On-time orders average 4.29
-- stars while late orders average 2.27, a gap of about 2 full points. (Order counts
-- here are slightly lower than in Q3 because some orders have no review.)


-- ----------------------------------------------------------
-- Q5. Which customer states have the highest late-delivery rate?
--     (states with at least 100 delivered orders)
-- ----------------------------------------------------------
WITH state_delivery AS (
    SELECT c.customer_state,
           COUNT(*) AS total_orders,
           SUM(CASE WHEN DATEDIFF(o.order_delivered_customer_date,
                                  o.order_estimated_delivery_date) > 0
                    THEN 1 ELSE 0 END) AS late_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY c.customer_state
)
SELECT customer_state,
       total_orders,
       late_orders,
       ROUND(100 * late_orders / total_orders, 2) AS late_pct
FROM state_delivery
WHERE total_orders >= 100
ORDER BY late_pct DESC
LIMIT 10;
-- Insight: Late deliveries are not spread evenly. Alagoas (AL) is the worst at 21.4%,
-- about three times the overall 6.8% rate, followed by Maranhao (MA) at 17.4% and
-- Sergipe (SE) at 15.2%. Most of the top 10 are northeastern states. Rio de Janeiro
-- looks milder at 12.1%, but with so many orders it has the highest count of late
-- deliveries in this list (1,495).


-- ----------------------------------------------------------
-- Q6. Which sellers have the most late deliveries?
--     (sellers with at least 50 delivered orders)
-- ----------------------------------------------------------
SELECT oi.seller_id,
       s.seller_state,
       COUNT(DISTINCT o.order_id) AS total_orders,
       COUNT(DISTINCT CASE WHEN DATEDIFF(o.order_delivered_customer_date,
                                         o.order_estimated_delivery_date) > 0
                           THEN o.order_id END) AS late_orders,
       ROUND(100 * COUNT(DISTINCT CASE WHEN DATEDIFF(o.order_delivered_customer_date,
                                                     o.order_estimated_delivery_date) > 0
                                       THEN o.order_id END)
                 / COUNT(DISTINCT o.order_id), 2) AS late_pct
FROM order_items oi
JOIN orders o  ON oi.order_id = o.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY oi.seller_id, s.seller_state
HAVING total_orders >= 50
ORDER BY late_orders DESC
LIMIT 10;
-- Insight: I ranked sellers by number of late orders, so big sellers naturally come
-- first. All ten are based in Sao Paulo (SP). The top one has 172 late orders out of
-- 1,772 (9.7%). Rates vary a lot though: one seller has the highest rate at 10.5%,
-- while a few high-volume sellers sit around 5.3%, below the 6.8% average. So volume
-- and lateness are not the same thing, and I would sort by late rate when hunting
-- for problem sellers.


-- ----------------------------------------------------------
-- Q7. Which product categories get the lowest review scores?
--     (categories with at least 100 reviewed orders)
-- ----------------------------------------------------------
WITH review_per_order AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
),
order_category AS (
    SELECT DISTINCT oi.order_id,
           COALESCE(t.product_category_name_english,
                    NULLIF(p.product_category_name, ''), 'unknown') AS category
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN category_translation t
           ON p.product_category_name = t.product_category_name
)
SELECT oc.category,
       COUNT(*)                      AS orders,
       ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_category oc
JOIN review_per_order r ON oc.order_id = r.order_id
GROUP BY oc.category
HAVING COUNT(*) >= 100
ORDER BY avg_review_score ASC
LIMIT 10;
-- Insight: office_furniture has the lowest average review at 3.62 across 1,263 orders,
-- followed by fashion_male_clothing (3.70, but only 111 orders) and audio (3.83).
-- These gaps look small next to the late-delivery effect in Q4, but bed_bath_table
-- stands out for volume: 9,313 orders at 3.97. I have not tested why furniture scores
-- lower. Bulky items arriving late or damaged would be my first thing to check. The
-- 'unknown' row is products with no category recorded in the data.


-- ----------------------------------------------------------
-- Q8. How many days late are orders, and does the review
--     score drop as delays grow?
-- ----------------------------------------------------------
WITH review_per_order AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
),
delivery AS (
    SELECT order_id,
           DATEDIFF(order_delivered_customer_date,
                    order_estimated_delivery_date) AS days_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)
SELECT CASE WHEN d.days_late <= 0  THEN '1. On time / early'
            WHEN d.days_late <= 3  THEN '2. 1-3 days late'
            WHEN d.days_late <= 7  THEN '3. 4-7 days late'
            WHEN d.days_late <= 14 THEN '4. 8-14 days late'
            ELSE '5. 15+ days late' END AS delay_bucket,
       COUNT(*)                         AS orders,
       ROUND(AVG(r.review_score), 2)    AS avg_review_score
FROM delivery d
JOIN review_per_order r ON d.order_id = r.order_id
GROUP BY delay_bucket
ORDER BY delay_bucket;
-- Insight: Reviews drop fast as delays grow. On-time orders average 4.29, but even
-- 1 to 3 days late brings it down to 3.29, and by 4 to 7 days it is 2.11. After about
-- a week it bottoms out around 1.7 (1.67 for 8 to 14 days, 1.73 for 15+). So most of
-- the damage happens in the first week, and being only a little late already costs
-- a lot.


-- ----------------------------------------------------------
-- Q9. Who are the top 10 customers by total spend?
--     customer_unique_id identifies a real person
--     (customer_id changes with every order).
-- ----------------------------------------------------------
WITH customer_spend AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id)    AS orders,
           ROUND(SUM(op.payment_value), 2) AS total_spent
    FROM customers c
    JOIN orders o          ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT customer_unique_id,
       orders,
       total_spent,
       RANK() OVER (ORDER BY total_spent DESC) AS spend_rank
FROM customer_spend
ORDER BY spend_rank
LIMIT 10;
-- Insight: The biggest spender paid R$13,664 in a single order, about 1.8 times the
-- second customer (R$7,572). Eight of the top ten customers placed only one order,
-- so top spend here comes from one-off big purchases, not repeat buying. Only one
-- customer on the list has more than two orders (4 orders, R$4,656). Spend includes
-- freight, since it is based on payment value.


-- ----------------------------------------------------------
-- Q10. What is the month-over-month revenue growth?
-- ----------------------------------------------------------
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
           SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY order_month
)
SELECT order_month,
       ROUND(revenue, 2) AS revenue,
       ROUND(LAG(revenue) OVER (ORDER BY order_month), 2) AS prev_month_revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
                 / LAG(revenue) OVER (ORDER BY order_month), 2) AS mom_growth_pct
FROM monthly
ORDER BY order_month;
-- Insight: Revenue climbed from about R$112K in Jan 2017 to a peak of R$988K in Nov
-- 2017 (up 52% that month), then fell 26.5% in Dec. In 2018 it flattened out, with
-- monthly changes between -12% and +27% and revenue staying around R$840K to R$978K
-- from Apr to Aug. The huge percentages in late 2016 and Jan 2017 (like 29,777% and
-- 1,025,573%) only happen because those months started from almost nothing, so I
-- ignore them.
