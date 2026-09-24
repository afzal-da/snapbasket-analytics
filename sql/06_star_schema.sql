-- ============================================================
-- SnapBasket Analytics
-- 06_star_schema.sql
--
-- Purpose:
-- Build the analytical star schema from the validated
-- analytics.fact_order_lines table.
--
-- Source fact:
--   analytics.fact_order_lines
--
-- Business population:
--   account_type = 'CUSTOMER'
--
-- INTERNAL_TEST records are retained for traceability but are
-- NOT removed from the analytical warehouse.
--
-- Grain:
--   fact_orders           = one row per order
--   fact_order_lines_star = one row per order line
-- ============================================================


-- ============================================================
-- SECTION 1: CLEAN PREVIOUS ANALYTICAL OBJECTS
-- ============================================================

-- These are analytical objects created by this script.
-- The original validated fact_order_lines table is NOT dropped.

DROP TABLE IF EXISTS analytics.fact_order_lines_star CASCADE;
DROP TABLE IF EXISTS analytics.fact_orders CASCADE;

DROP TABLE IF EXISTS analytics.dim_date CASCADE;
DROP TABLE IF EXISTS analytics.dim_customer CASCADE;
DROP TABLE IF EXISTS analytics.dim_product CASCADE;
DROP TABLE IF EXISTS analytics.dim_store CASCADE;


-- ============================================================
-- SECTION 2: DATE DIMENSION
-- ============================================================

CREATE TABLE analytics.dim_date (
    date_key        INTEGER PRIMARY KEY,
    full_date       DATE NOT NULL UNIQUE,
    year            INTEGER NOT NULL,
    quarter         INTEGER NOT NULL,
    month           INTEGER NOT NULL,
    month_name      VARCHAR(20) NOT NULL,
    week_of_year    INTEGER NOT NULL,
    day_of_month    INTEGER NOT NULL,
    day_name        VARCHAR(20) NOT NULL,
    day_of_week     INTEGER NOT NULL,
    is_weekend      BOOLEAN NOT NULL
);


-- Generate one row for every calendar date represented in
-- the source dataset.

INSERT INTO analytics.dim_date (
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    week_of_year,
    day_of_month,
    day_name,
    day_of_week,
    is_weekend
)
SELECT
    TO_CHAR(d::DATE, 'YYYYMMDD')::INTEGER AS date_key,
    d::DATE AS full_date,
    EXTRACT(YEAR FROM d)::INTEGER AS year,
    EXTRACT(QUARTER FROM d)::INTEGER AS quarter,
    EXTRACT(MONTH FROM d)::INTEGER AS month,
    TO_CHAR(d, 'Month') AS month_name,
    EXTRACT(WEEK FROM d)::INTEGER AS week_of_year,
    EXTRACT(DAY FROM d)::INTEGER AS day_of_month,
    TO_CHAR(d, 'Day') AS day_name,
    EXTRACT(ISODOW FROM d)::INTEGER AS day_of_week,
    EXTRACT(ISODOW FROM d)::INTEGER IN (6, 7) AS is_weekend
FROM generate_series(
    (
        SELECT MIN(order_datetime)::DATE
        FROM analytics.fact_order_lines
    ),
    (
        SELECT MAX(order_datetime)::DATE
        FROM analytics.fact_order_lines
    ),
    INTERVAL '1 day'
) AS gs(d);


-- ============================================================
-- SECTION 3: CUSTOMER DIMENSION
-- ============================================================

CREATE TABLE analytics.dim_customer (
    customer_key    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     VARCHAR(50) NOT NULL UNIQUE
);


INSERT INTO analytics.dim_customer (
    customer_id
)
SELECT DISTINCT
    customer_id
FROM analytics.fact_order_lines
WHERE customer_id IS NOT NULL
ORDER BY customer_id;


-- ============================================================
-- SECTION 4: PRODUCT DIMENSION
-- ============================================================

CREATE TABLE analytics.dim_product (
    product_key     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id      VARCHAR(50) NOT NULL UNIQUE,
    product_name    VARCHAR(255) NOT NULL,
    category        VARCHAR(100) NOT NULL,
    unit_price      NUMERIC(12,2)
);


INSERT INTO analytics.dim_product (
    product_id,
    product_name,
    category,
    unit_price
)
SELECT
    product_id,
    MAX(product_name) AS product_name,
    MAX(category) AS category,
    MAX(unit_price) AS unit_price
FROM analytics.fact_order_lines
GROUP BY product_id
ORDER BY product_id;


-- ============================================================
-- SECTION 5: STORE DIMENSION
-- ============================================================

CREATE TABLE analytics.dim_store (
    store_key       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id        VARCHAR(50) NOT NULL UNIQUE,
    store_city      VARCHAR(100) NOT NULL,
    store_type      VARCHAR(100) NOT NULL
);


INSERT INTO analytics.dim_store (
    store_id,
    store_city,
    store_type
)
SELECT
    store_id,
    MAX(store_city) AS store_city,
    MAX(store_type) AS store_type
FROM analytics.fact_order_lines
GROUP BY store_id
ORDER BY store_id;


-- ============================================================
-- SECTION 6: ORDER-LEVEL FACT TABLE
-- ============================================================

-- Grain:
-- One row = one order.
--
-- This table exists because order-level KPIs such as:
--   - Orders
--   - AOV
--   - Delivery performance
--   - Repeat purchase behaviour
--   - Order status
--
-- should not require repeated DISTINCT order_id logic against
-- the line-item fact table.
--
-- IMPORTANT:
-- payment_method is intentionally NOT included here.
-- The source contains multiple payment methods within the
-- same order, so payment_method belongs at line-item grain
-- in fact_order_lines_star.

CREATE TABLE analytics.fact_orders (
    order_key               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    order_id                VARCHAR(50) NOT NULL UNIQUE,

    order_date_key          INTEGER NOT NULL,
    customer_key            BIGINT NOT NULL,
    store_key               BIGINT NOT NULL,

    customer_id             VARCHAR(50) NOT NULL,
    customer_city           VARCHAR(100),
    account_type            VARCHAR(50) NOT NULL,

    store_id                VARCHAR(50) NOT NULL,

    order_datetime          TIMESTAMPTZ NOT NULL,
    delivery_datetime       TIMESTAMPTZ,

    order_status            VARCHAR(50) NOT NULL,

    line_item_count         INTEGER NOT NULL,

    total_quantity          NUMERIC(14,2) NOT NULL,
    gross_amount            NUMERIC(14,2) NOT NULL,
    discount_amount         NUMERIC(14,2) NOT NULL,
    net_amount              NUMERIC(14,2) NOT NULL,

    delivery_fee            NUMERIC(14,2) NOT NULL,
    packaging_fee           NUMERIC(14,2) NOT NULL,
    billed_amount           NUMERIC(14,2) NOT NULL,

    delivery_minutes        NUMERIC(12,2),
    sla_minutes             NUMERIC(12,2),
    sla_breached            BOOLEAN,

    support_ticket_count    INTEGER NOT NULL,

    avg_csat_score          NUMERIC(5,2)
);


INSERT INTO analytics.fact_orders (
    order_id,
    order_date_key,
    customer_key,
    store_key,
    customer_id,
    customer_city,
    account_type,
    store_id,
    order_datetime,
    delivery_datetime,
    order_status,
    line_item_count,
    total_quantity,
    gross_amount,
    discount_amount,
    net_amount,
    delivery_fee,
    packaging_fee,
    billed_amount,
    delivery_minutes,
    sla_minutes,
    sla_breached,
    support_ticket_count,
    avg_csat_score
)
SELECT
    f.order_id,

    TO_CHAR(
        MIN(f.order_datetime)::DATE,
        'YYYYMMDD'
    )::INTEGER AS order_date_key,

    c.customer_key,
    s.store_key,

    MIN(f.customer_id) AS customer_id,
    MIN(f.customer_city) AS customer_city,
    MIN(f.account_type) AS account_type,

    MIN(f.store_id) AS store_id,

    MIN(f.order_datetime) AS order_datetime,
    MAX(f.delivery_datetime) AS delivery_datetime,

    MIN(f.order_status) AS order_status,

    COUNT(*)::INTEGER AS line_item_count,

    SUM(f.quantity) AS total_quantity,
    SUM(f.gross_amount) AS gross_amount,
    SUM(f.discount_amount) AS discount_amount,
    SUM(f.net_amount) AS net_amount,

    -- delivery fee is repeated on every line,
    -- therefore MAX() retrieves the order-level fee.
    MAX(f.order_delivery_fee) AS delivery_fee,

    SUM(f.packaging_fee) AS packaging_fee,

    SUM(f.billed_amount) AS billed_amount,

    MAX(f.delivery_minutes) AS delivery_minutes,
    MAX(f.sla_minutes) AS sla_minutes,

    BOOL_OR(f.sla_breached) AS sla_breached,

    COUNT(DISTINCT f.support_ticket_id)
        FILTER (
            WHERE f.support_ticket_id IS NOT NULL
        )::INTEGER AS support_ticket_count,

    ROUND(
        AVG(f.csat_score),
        2
    ) AS avg_csat_score

FROM analytics.fact_order_lines f

INNER JOIN analytics.dim_customer c
    ON f.customer_id = c.customer_id

INNER JOIN analytics.dim_store s
    ON f.store_id = s.store_id

GROUP BY
    f.order_id,
    c.customer_key,
    s.store_key;


-- ============================================================
-- SECTION 7: LINE-ITEM FACT TABLE FOR THE STAR SCHEMA
-- ============================================================

-- Grain:
-- One row = one order line item.
--
-- This is the product-level analytical fact table.

CREATE TABLE analytics.fact_order_lines_star (
    line_item_key           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    line_item_id            VARCHAR(50) NOT NULL UNIQUE,
    order_key               BIGINT NOT NULL,

    order_date_key          INTEGER NOT NULL,
    customer_key            BIGINT NOT NULL,
    product_key             BIGINT NOT NULL,
    store_key               BIGINT NOT NULL,

    order_id                VARCHAR(50) NOT NULL,
    customer_id             VARCHAR(50) NOT NULL,
    customer_city           VARCHAR(100),
    account_type            VARCHAR(50) NOT NULL,

    store_id                VARCHAR(50) NOT NULL,
    product_id              VARCHAR(50) NOT NULL,

    order_datetime          TIMESTAMPTZ NOT NULL,
    delivery_datetime       TIMESTAMPTZ,

    order_status            VARCHAR(50) NOT NULL,

    quantity                NUMERIC(14,2) NOT NULL,
    unit_price              NUMERIC(14,2) NOT NULL,

    gross_amount            NUMERIC(14,2) NOT NULL,
    discount_amount         NUMERIC(14,2) NOT NULL,
    net_amount              NUMERIC(14,2) NOT NULL,

    order_delivery_fee      NUMERIC(14,2) NOT NULL,
    allocated_delivery_fee  NUMERIC(14,2) NOT NULL,

    packaging_fee           NUMERIC(14,2) NOT NULL,
    billed_amount           NUMERIC(14,2) NOT NULL,

    payment_method          VARCHAR(50),

    delivery_partner_id     VARCHAR(50),

    delivery_minutes        NUMERIC(12,2),
    sla_minutes             NUMERIC(12,2),
    sla_breached            BOOLEAN,

    support_ticket_id       VARCHAR(100),
    ticket_category         VARCHAR(100),
    csat_score              NUMERIC(5,2),

    line_item_count         INTEGER NOT NULL
);


INSERT INTO analytics.fact_order_lines_star (
    line_item_id,
    order_key,

    order_date_key,
    customer_key,
    product_key,
    store_key,

    order_id,
    customer_id,
    customer_city,
    account_type,

    store_id,
    product_id,

    order_datetime,
    delivery_datetime,

    order_status,

    quantity,
    unit_price,

    gross_amount,
    discount_amount,
    net_amount,

    order_delivery_fee,
    allocated_delivery_fee,

    packaging_fee,
    billed_amount,

    payment_method,

    delivery_partner_id,

    delivery_minutes,
    sla_minutes,
    sla_breached,

    support_ticket_id,
    ticket_category,
    csat_score,

    line_item_count
)
SELECT
    f.line_item_id,

    o.order_key,

    TO_CHAR(
        f.order_datetime::DATE,
        'YYYYMMDD'
    )::INTEGER AS order_date_key,

    c.customer_key,
    p.product_key,
    s.store_key,

    f.order_id,
    f.customer_id,
    f.customer_city,
    f.account_type,

    f.store_id,
    f.product_id,

    f.order_datetime,
    f.delivery_datetime,

    f.order_status,

    f.quantity,
    f.unit_price,

    f.gross_amount,
    f.discount_amount,
    f.net_amount,

    f.order_delivery_fee,
    f.allocated_delivery_fee,

    f.packaging_fee,
    f.billed_amount,

    f.payment_method,

    f.delivery_partner_id,

    f.delivery_minutes,
    f.sla_minutes,
    f.sla_breached,

    f.support_ticket_id,
    f.ticket_category,
    f.csat_score,

    f.line_item_count

FROM analytics.fact_order_lines f

INNER JOIN analytics.fact_orders o
    ON f.order_id = o.order_id

INNER JOIN analytics.dim_customer c
    ON f.customer_id = c.customer_id

INNER JOIN analytics.dim_product p
    ON f.product_id = p.product_id

INNER JOIN analytics.dim_store s
    ON f.store_id = s.store_id;


-- ============================================================
-- SECTION 8: FOREIGN KEYS
-- ============================================================

ALTER TABLE analytics.fact_orders
ADD CONSTRAINT fk_fact_orders_date
FOREIGN KEY (order_date_key)
REFERENCES analytics.dim_date(date_key);

ALTER TABLE analytics.fact_orders
ADD CONSTRAINT fk_fact_orders_customer
FOREIGN KEY (customer_key)
REFERENCES analytics.dim_customer(customer_key);

ALTER TABLE analytics.fact_orders
ADD CONSTRAINT fk_fact_orders_store
FOREIGN KEY (store_key)
REFERENCES analytics.dim_store(store_key);


ALTER TABLE analytics.fact_order_lines_star
ADD CONSTRAINT fk_fact_lines_order
FOREIGN KEY (order_key)
REFERENCES analytics.fact_orders(order_key);

ALTER TABLE analytics.fact_order_lines_star
ADD CONSTRAINT fk_fact_lines_date
FOREIGN KEY (order_date_key)
REFERENCES analytics.dim_date(date_key);

ALTER TABLE analytics.fact_order_lines_star
ADD CONSTRAINT fk_fact_lines_customer
FOREIGN KEY (customer_key)
REFERENCES analytics.dim_customer(customer_key);

ALTER TABLE analytics.fact_order_lines_star
ADD CONSTRAINT fk_fact_lines_product
FOREIGN KEY (product_key)
REFERENCES analytics.dim_product(product_key);

ALTER TABLE analytics.fact_order_lines_star
ADD CONSTRAINT fk_fact_lines_store
FOREIGN KEY (store_key)
REFERENCES analytics.dim_store(store_key);


-- ============================================================
-- SECTION 9: PERFORMANCE INDEXES
-- ============================================================

CREATE INDEX idx_fact_orders_date
ON analytics.fact_orders(order_date_key);

CREATE INDEX idx_fact_orders_customer
ON analytics.fact_orders(customer_key);

CREATE INDEX idx_fact_orders_store
ON analytics.fact_orders(store_key);

CREATE INDEX idx_fact_orders_account_type
ON analytics.fact_orders(account_type);

CREATE INDEX idx_fact_orders_status
ON analytics.fact_orders(order_status);


CREATE INDEX idx_fact_lines_order
ON analytics.fact_order_lines_star(order_key);

CREATE INDEX idx_fact_lines_date
ON analytics.fact_order_lines_star(order_date_key);

CREATE INDEX idx_fact_lines_customer
ON analytics.fact_order_lines_star(customer_key);

CREATE INDEX idx_fact_lines_product
ON analytics.fact_order_lines_star(product_key);

CREATE INDEX idx_fact_lines_store
ON analytics.fact_order_lines_star(store_key);

CREATE INDEX idx_fact_lines_account_type
ON analytics.fact_order_lines_star(account_type);

CREATE INDEX idx_fact_lines_status
ON analytics.fact_order_lines_star(order_status);


-- ============================================================
-- SECTION 10: STAR-SCHEMA VALIDATION
-- ============================================================


-- ------------------------------------------------------------
-- 10.1 Dimension counts
-- ------------------------------------------------------------

SELECT
    'dim_date' AS table_name,
    COUNT(*) AS row_count
FROM analytics.dim_date

UNION ALL

SELECT
    'dim_customer',
    COUNT(*)
FROM analytics.dim_customer

UNION ALL

SELECT
    'dim_product',
    COUNT(*)
FROM analytics.dim_product

UNION ALL

SELECT
    'dim_store',
    COUNT(*)
FROM analytics.dim_store

UNION ALL

SELECT
    'fact_orders',
    COUNT(*)
FROM analytics.fact_orders

UNION ALL

SELECT
    'fact_order_lines_star',
    COUNT(*)
FROM analytics.fact_order_lines_star

ORDER BY table_name;


-- ------------------------------------------------------------
-- 10.2 Grain validation
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS line_rows,
    COUNT(DISTINCT line_item_id) AS unique_line_items,
    COUNT(DISTINCT order_id) AS orders
FROM analytics.fact_order_lines_star;


SELECT
    COUNT(*) AS order_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM analytics.fact_orders;


-- ------------------------------------------------------------
-- 10.3 Compare original fact with star-schema fact
-- ------------------------------------------------------------

SELECT
    (
        SELECT COUNT(*)
        FROM analytics.fact_order_lines
    ) AS original_fact_rows,

    (
        SELECT COUNT(*)
        FROM analytics.fact_order_lines_star
    ) AS star_fact_rows;


-- ------------------------------------------------------------
-- 10.4 Billing reconciliation
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE ABS(
            billed_amount
            -
            (
                net_amount
                + packaging_fee
                + allocated_delivery_fee
            )
        ) > 0.01
    ) AS billing_mismatches

FROM analytics.fact_order_lines_star;


-- ------------------------------------------------------------
-- 10.5 Order-to-line reconciliation
-- ------------------------------------------------------------

SELECT
    (
        SELECT COUNT(*)
        FROM analytics.fact_orders
    ) AS fact_orders,

    (
        SELECT COUNT(DISTINCT order_id)
        FROM analytics.fact_order_lines_star
    ) AS line_fact_orders;


-- ------------------------------------------------------------
-- 10.6 Business population
-- ------------------------------------------------------------

SELECT
    account_type,
    COUNT(*) AS orders,
    ROUND(SUM(billed_amount), 2) AS billed_amount,
    ROUND(
        SUM(billed_amount)
        / NULLIF(COUNT(*), 0),
        2
    ) AS average_order_value
FROM analytics.fact_orders
GROUP BY account_type
ORDER BY account_type;


-- ------------------------------------------------------------
-- 10.7 Customer-business population
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS customer_orders,
    COUNT(DISTINCT customer_key) AS customers,
    ROUND(SUM(billed_amount), 2) AS billed_amount
FROM analytics.fact_orders
WHERE account_type = 'CUSTOMER';


-- ------------------------------------------------------------
-- 10.8 Internal-test population
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS internal_test_orders,
    COUNT(DISTINCT customer_key) AS internal_test_customers,
    ROUND(SUM(billed_amount), 2) AS billed_amount
FROM analytics.fact_orders
WHERE account_type = 'INTERNAL_TEST';