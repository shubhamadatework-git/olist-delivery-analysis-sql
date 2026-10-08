USE olist_analysis;

-- Check 1: What order statuses exist, and how many of each?
SELECT order_status, COUNT(*) AS orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- Check 2: What date range does the data cover?
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order
FROM orders;

-- Check 3: Delivered orders that are missing a delivery date
SELECT COUNT(*) AS missing_delivery_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- Check 4: Orders with more than one review
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (SELECT order_id FROM order_reviews
      GROUP BY order_id HAVING COUNT(*) > 1) t;

















