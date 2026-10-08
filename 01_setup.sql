/* ==========================================================
   Project : Olist E-Commerce: Delivery Performance & Customer Satisfaction
   File    : 01_setup.sql (create database, tables and load data)
   Author  : Shubham Adate
   Tool    : MySQL 8.0
   Dataset : Olist Brazilian E-Commerce (Kaggle)
   Goal    : Find how late deliveries affect review scores
             and which sellers, states and categories drive it

   Before running:
   - Copy the 9 Olist CSV files into the folder MySQL allows for
     imports. Check yours with: SHOW VARIABLES LIKE 'secure_file_priv';
   - If your folder path is different, update the paths below.
   ========================================================== */


/* ----------------------------------------------------------
   1. DATABASE
   DROP makes the script safe to re-run from scratch.
   ---------------------------------------------------------- */
DROP DATABASE IF EXISTS olist_analysis;
CREATE DATABASE olist_analysis;
USE olist_analysis;


/* ----------------------------------------------------------
   2. TABLES
   Table names are shortened for readability.
   order_reviews and geolocation have no primary key on purpose:
   both contain duplicate IDs in the raw data.
   ---------------------------------------------------------- */

CREATE TABLE customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state VARCHAR(5),
    PRIMARY KEY (customer_id)
);

CREATE TABLE sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state VARCHAR(5),
    PRIMARY KEY (seller_id)
);

CREATE TABLE products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
    PRIMARY KEY (product_id)
);

CREATE TABLE category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100),
    PRIMARY KEY (product_category_name)
);

CREATE TABLE orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(20),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    PRIMARY KEY (order_id)
);

CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(30),
    payment_installments INT,
    payment_value DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE order_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);

CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(18,15),
    geolocation_lng DECIMAL(18,15),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(5)
);


/* ----------------------------------------------------------
   3. LOAD DATA
   Use forward slashes in the path. Empty values in numeric and
   date columns are converted to NULL with NULLIF.
   ---------------------------------------------------------- */

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_customers_dataset.csv'
INTO TABLE customers CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_sellers_dataset.csv'
INTO TABLE sellers CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/product_category_name_translation.csv'
INTO TABLE category_translation CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_products_dataset.csv'
INTO TABLE products CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(product_id, product_category_name, @name_len, @desc_len, @photos,
 @weight, @length, @height, @width)
SET product_name_length = NULLIF(@name_len,''),
    product_description_length = NULLIF(@desc_len,''),
    product_photos_qty = NULLIF(@photos,''),
    product_weight_g = NULLIF(@weight,''),
    product_length_cm = NULLIF(@length,''),
    product_height_cm = NULLIF(@height,''),
    product_width_cm = NULLIF(@width,'');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_orders_dataset.csv'
INTO TABLE orders CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, customer_id, order_status, @purchase, @approved,
 @carrier, @delivered, @estimated)
SET order_purchase_timestamp = NULLIF(@purchase,''),
    order_approved_at = NULLIF(@approved,''),
    order_delivered_carrier_date = NULLIF(@carrier,''),
    order_delivered_customer_date = NULLIF(@delivered,''),
    order_estimated_delivery_date = NULLIF(@estimated,'');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_items_dataset.csv'
INTO TABLE order_items CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_payments_dataset.csv'
INTO TABLE order_payments CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

-- Reviews contain quotes and line breaks inside comments,
-- so quotes are treated as escaped by doubling them ("").
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(review_id, order_id, review_score, review_comment_title,
 review_comment_message, @created, @answered)
SET review_creation_date = NULLIF(@created,''),
    review_answer_timestamp = NULLIF(@answered,'');

-- Largest file (about 1 million rows): takes up to a minute.
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_geolocation_dataset.csv'
INTO TABLE geolocation CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

/* ----------------------------------------------------------
   4. FOREIGN KEYS
   Added after loading so the import runs fast.
   category_translation and geolocation are left unlinked on
   purpose: some products have no translated category, and
   zip prefixes repeat in geolocation so they cannot be a key.
   ---------------------------------------------------------- */
ALTER TABLE orders
  ADD CONSTRAINT fk_orders_customer
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

ALTER TABLE order_items
  ADD CONSTRAINT fk_items_order
  FOREIGN KEY (order_id) REFERENCES orders(order_id),
  ADD CONSTRAINT fk_items_product
  FOREIGN KEY (product_id) REFERENCES products(product_id),
  ADD CONSTRAINT fk_items_seller
  FOREIGN KEY (seller_id) REFERENCES sellers(seller_id);

ALTER TABLE order_payments
  ADD CONSTRAINT fk_payments_order
  FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE order_reviews
  ADD CONSTRAINT fk_reviews_order
  FOREIGN KEY (order_id) REFERENCES orders(order_id);

/* ----------------------------------------------------------
   5. VERIFY ROW COUNTS
   Expected: customers 99441, sellers 3095, products 32951,
   category_translation 71, orders 99441, order_items 112650,
   order_payments 103886, order_reviews 99224, geolocation 1000163
   ---------------------------------------------------------- */
SELECT 'customers' AS tbl, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation;
