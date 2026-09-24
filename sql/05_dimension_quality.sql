-- ============================================================
-- SNAPBASKET ANALYTICS
-- 05 - DIMENSION QUALITY VALIDATION
-- ============================================================


-- ============================================================
-- 1. CUSTOMER CONSISTENCY
-- Does each customer have one account type and city?
-- ============================================================

SELECT
    customer_id,
    COUNT(DISTINCT account_type) AS account_types,
    COUNT(DISTINCT customer_city) AS customer_cities
FROM analytics.fact_order_lines
GROUP BY customer_id
HAVING COUNT(DISTINCT account_type) > 1
    OR COUNT(DISTINCT customer_city) > 1
ORDER BY customer_id;


-- ============================================================
-- 2. PRODUCT CONSISTENCY
-- Does each product ID map to one product name/category?
-- ============================================================

SELECT
    product_id,
    COUNT(DISTINCT product_name) AS product_names,
    COUNT(DISTINCT category) AS categories
FROM analytics.fact_order_lines
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1
    OR COUNT(DISTINCT category) > 1
ORDER BY product_id;


-- ============================================================
-- 3. PRODUCT PRICE VARIATION
-- A product can legitimately have different prices.
-- We need to measure it, not assume it.
-- ============================================================

SELECT
    product_id,
    product_name,
    COUNT(DISTINCT unit_price) AS distinct_prices,
    MIN(unit_price) AS minimum_price,
    MAX(unit_price) AS maximum_price
FROM analytics.fact_order_lines
GROUP BY
    product_id,
    product_name
HAVING COUNT(DISTINCT unit_price) > 1
ORDER BY distinct_prices DESC;


-- ============================================================
-- 4. STORE CONSISTENCY
-- Does each store map to one city/type?
-- ============================================================

SELECT
    store_id,
    COUNT(DISTINCT store_city) AS store_cities,
    COUNT(DISTINCT store_type) AS store_types
FROM analytics.fact_order_lines
GROUP BY store_id
HAVING COUNT(DISTINCT store_city) > 1
    OR COUNT(DISTINCT store_type) > 1
ORDER BY store_id;


-- ============================================================
-- 5. CUSTOMER COUNT
-- ============================================================

SELECT
    COUNT(DISTINCT customer_id) AS customers
FROM analytics.fact_order_lines;


-- ============================================================
-- 6. PRODUCT COUNT
-- ============================================================

SELECT
    COUNT(DISTINCT product_id) AS products
FROM analytics.fact_order_lines;


-- ============================================================
-- 7. STORE COUNT
-- ============================================================

SELECT
    COUNT(DISTINCT store_id) AS stores
FROM analytics.fact_order_lines;


-- ============================================================
-- 8. CATEGORY COUNT
-- ============================================================

SELECT
    COUNT(DISTINCT category) AS categories
FROM analytics.fact_order_lines;


-- ============================================================
-- 9. CITY COUNT
-- ============================================================

SELECT
    COUNT(DISTINCT customer_city) AS customer_cities,
    COUNT(DISTINCT store_city) AS store_cities
FROM analytics.fact_order_lines;