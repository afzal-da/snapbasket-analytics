-- ============================================================
-- SnapBasket Analytics
-- 07_kpi_layer.sql
-- Purpose: Business KPI / semantic layer
-- Grain: Depends on the individual view
-- Default population: account_type = 'CUSTOMER'
-- ============================================================


-- ============================================================
-- 0. CLEAN PREVIOUS KPI OBJECTS
-- ============================================================

DROP VIEW IF EXISTS analytics.v_kpi_overall CASCADE;
DROP VIEW IF EXISTS analytics.v_kpi_monthly CASCADE;
DROP VIEW IF EXISTS analytics.v_kpi_city CASCADE;
DROP VIEW IF EXISTS analytics.v_kpi_store CASCADE;
DROP VIEW IF EXISTS analytics.v_kpi_category CASCADE;
DROP VIEW IF EXISTS analytics.v_kpi_product CASCADE;
DROP VIEW IF EXISTS analytics.v_kpi_customer CASCADE;
DROP VIEW IF EXISTS analytics.v_kpi_operations CASCADE;


-- ============================================================
-- 1. OVERALL BUSINESS KPI VIEW
-- ============================================================

CREATE VIEW analytics.v_kpi_overall AS

WITH customer_order_counts AS (

    SELECT
        customer_id,
        COUNT(*) AS order_count
    FROM analytics.fact_orders
    WHERE account_type = 'CUSTOMER'
    GROUP BY customer_id

)

SELECT

    /* -------------------------
       Order KPIs
       ------------------------- */

    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE f.order_status = 'DELIVERED'
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE f.order_status = 'RETURNED'
    ) AS returned_orders,

    COUNT(*) FILTER (
        WHERE f.order_status = 'CANCELLED'
    ) AS cancelled_orders,

    COUNT(*) FILTER (
        WHERE f.order_status = 'PENDING'
    ) AS pending_orders,


    /* -------------------------
       Customer KPIs
       ------------------------- */

    COUNT(DISTINCT f.customer_id) AS total_customers,

    COUNT(DISTINCT f.customer_id) FILTER (
        WHERE c.order_count > 1
    ) AS repeat_customers,


    /* -------------------------
       Sales KPIs
       ------------------------- */

    ROUND(SUM(f.gross_amount), 2) AS gross_sales,

    ROUND(SUM(f.discount_amount), 2) AS total_discount,

    ROUND(SUM(f.net_amount), 2) AS net_sales,

    ROUND(SUM(f.billed_amount), 2) AS billed_amount,


    /* -------------------------
       Operational KPIs
       ------------------------- */

    SUM(f.total_quantity) AS total_units,

    ROUND(
        AVG(f.delivery_minutes)
        FILTER (
            WHERE f.order_status IN ('DELIVERED', 'RETURNED')
        ),
        2
    ) AS avg_delivery_minutes,

    ROUND(
        AVG(f.delivery_minutes)
        FILTER (
            WHERE f.order_status = 'DELIVERED'
        ),
        2
    ) AS avg_delivered_minutes,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE f.sla_breached = TRUE
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE f.order_status IN ('DELIVERED', 'RETURNED')
            ),
            0
        ),
        2
    ) AS sla_breach_rate_pct,


    /* -------------------------
       Customer Experience KPIs
       ------------------------- */

    ROUND(
    (
        SELECT AVG(l.csat_score)
        FROM analytics.fact_order_lines_star l
        WHERE l.account_type = 'CUSTOMER'
          AND l.csat_score IS NOT NULL
    ),
    2
) AS avg_csat,

ROUND(
    (
        SELECT AVG(l.csat_score)
        FROM analytics.fact_order_lines_star l
        WHERE l.account_type = 'CUSTOMER'
          AND l.order_status = 'DELIVERED'
          AND l.csat_score IS NOT NULL
    ),
    2
) AS delivered_avg_csat,

    SUM(f.support_ticket_count) AS support_tickets,


    /* -------------------------
       Rate KPIs
       ------------------------- */

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE f.order_status = 'CANCELLED'
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE f.order_status = 'RETURNED'
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS return_rate_pct,

    ROUND(
        100.0 * SUM(f.discount_amount)
        / NULLIF(SUM(f.gross_amount), 0),
        2
    ) AS discount_rate_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE f.order_status = 'DELIVERED'
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS delivery_completion_rate_pct

FROM analytics.fact_orders f

LEFT JOIN customer_order_counts c
    ON f.customer_id = c.customer_id

WHERE f.account_type = 'CUSTOMER';


-- ============================================================
-- 2. MONTHLY KPI VIEW
-- ============================================================

CREATE VIEW analytics.v_kpi_monthly AS
SELECT

    DATE_TRUNC('month', order_datetime)::date AS month_start,

    TO_CHAR(
        DATE_TRUNC('month', order_datetime),
        'YYYY-MM'
    ) AS month,

    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'DELIVERED'
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'RETURNED'
    ) AS returned_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'CANCELLED'
    ) AS cancelled_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'PENDING'
    ) AS pending_orders,

    COUNT(DISTINCT customer_id) AS total_customers,

    SUM(total_quantity) AS total_units,

    ROUND(SUM(gross_amount), 2) AS gross_sales,

    ROUND(SUM(discount_amount), 2) AS total_discount,

    ROUND(SUM(net_amount), 2) AS net_sales,

    ROUND(SUM(billed_amount), 2) AS billed_amount,

    ROUND(
        SUM(billed_amount)
        / NULLIF(COUNT(*), 0),
        2
    ) AS aov,

    ROUND(
        AVG(delivery_minutes)
        FILTER (
            WHERE order_status = 'DELIVERED'
        ),
        2
    ) AS avg_delivery_minutes,

    ROUND(
        AVG(avg_csat_score)
        FILTER (
            WHERE order_status = 'DELIVERED'
            AND avg_csat_score IS NOT NULL
        ),
        2
    ) AS avg_csat,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_status = 'CANCELLED'
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_status = 'RETURNED'
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS return_rate_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE sla_breached = TRUE
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE order_status IN ('DELIVERED', 'RETURNED')
            ),
            0
        ),
        2
    ) AS sla_breach_rate_pct

FROM analytics.fact_orders

WHERE account_type = 'CUSTOMER'

GROUP BY
    DATE_TRUNC('month', order_datetime)

ORDER BY
    month_start;


-- ============================================================
-- 3. CITY KPI VIEW
-- ============================================================

CREATE VIEW analytics.v_kpi_city AS
SELECT

    customer_city AS city,

    COUNT(*) AS total_orders,

    COUNT(DISTINCT customer_id) AS total_customers,

    COUNT(*) FILTER (
        WHERE order_status = 'DELIVERED'
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'RETURNED'
    ) AS returned_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'CANCELLED'
    ) AS cancelled_orders,

    SUM(total_quantity) AS total_units,

    ROUND(SUM(gross_amount), 2) AS gross_sales,

    ROUND(SUM(discount_amount), 2) AS total_discount,

    ROUND(SUM(net_amount), 2) AS net_sales,

    ROUND(SUM(billed_amount), 2) AS billed_amount,

    ROUND(
        SUM(billed_amount)
        / NULLIF(COUNT(*), 0),
        2
    ) AS aov,

    ROUND(
        AVG(delivery_minutes)
        FILTER (
            WHERE order_status = 'DELIVERED'
        ),
        2
    ) AS avg_delivery_minutes,

    ROUND(
        AVG(avg_csat_score)
        FILTER (
            WHERE order_status = 'DELIVERED'
            AND avg_csat_score IS NOT NULL
        ),
        2
    ) AS avg_csat,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_status = 'CANCELLED'
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_status = 'RETURNED'
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS return_rate_pct

FROM analytics.fact_orders

WHERE account_type = 'CUSTOMER'

GROUP BY customer_city;


-- ============================================================
-- 4. STORE KPI VIEW
-- ============================================================

CREATE VIEW analytics.v_kpi_store AS
SELECT

    f.store_id,

    d.store_city,

    d.store_type,

    COUNT(*) AS total_orders,

    COUNT(DISTINCT f.customer_id) AS total_customers,

    COUNT(*) FILTER (
        WHERE f.order_status = 'DELIVERED'
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE f.order_status = 'RETURNED'
    ) AS returned_orders,

    COUNT(*) FILTER (
        WHERE f.order_status = 'CANCELLED'
    ) AS cancelled_orders,

    ROUND(SUM(f.gross_amount), 2) AS gross_sales,

    ROUND(SUM(f.discount_amount), 2) AS total_discount,

    ROUND(SUM(f.net_amount), 2) AS net_sales,

    ROUND(SUM(f.billed_amount), 2) AS billed_amount,

    ROUND(
        SUM(f.billed_amount)
        / NULLIF(COUNT(*), 0),
        2
    ) AS aov,

    ROUND(
        AVG(f.delivery_minutes)
        FILTER (
            WHERE f.order_status = 'DELIVERED'
        ),
        2
    ) AS avg_delivery_minutes,

    ROUND(
        AVG(f.avg_csat_score)
        FILTER (
            WHERE f.order_status = 'DELIVERED'
            AND f.avg_csat_score IS NOT NULL
        ),
        2
    ) AS avg_csat,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE f.order_status = 'CANCELLED'
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS cancellation_rate_pct

FROM analytics.fact_orders f

LEFT JOIN analytics.dim_store d
    ON f.store_key = d.store_key

WHERE f.account_type = 'CUSTOMER'

GROUP BY
    f.store_id,
    d.store_city,
    d.store_type;


-- ============================================================
-- 5. CATEGORY KPI VIEW
-- ============================================================

CREATE VIEW analytics.v_kpi_category AS
SELECT

    d.category,

    COUNT(*) AS total_order_lines,

    COUNT(DISTINCT f.order_id) AS total_orders,

    COUNT(DISTINCT f.customer_id) AS total_customers,

    SUM(f.quantity) AS total_units,

    ROUND(SUM(f.gross_amount), 2) AS gross_sales,

    ROUND(SUM(f.discount_amount), 2) AS total_discount,

    ROUND(SUM(f.net_amount), 2) AS net_sales,

    ROUND(SUM(f.billed_amount), 2) AS billed_amount,

    ROUND(
        100.0 * SUM(f.billed_amount)
        / NULLIF(
            SUM(SUM(f.billed_amount)) OVER (),
            0
        ),
        2
    ) AS billed_amount_share_pct

FROM analytics.fact_order_lines_star f

LEFT JOIN analytics.dim_product d
    ON f.product_key = d.product_key

WHERE f.account_type = 'CUSTOMER'

GROUP BY
    d.category;


-- ============================================================
-- 6. PRODUCT KPI VIEW
-- ============================================================

CREATE VIEW analytics.v_kpi_product AS
SELECT

    f.product_id,

    d.product_name,

    d.category,

    COUNT(DISTINCT f.order_id) AS total_orders,

    COUNT(DISTINCT f.customer_id) AS total_customers,

    SUM(f.quantity) AS units_sold,

    ROUND(SUM(f.gross_amount), 2) AS gross_sales,

    ROUND(SUM(f.discount_amount), 2) AS total_discount,

    ROUND(SUM(f.net_amount), 2) AS net_sales,

    ROUND(SUM(f.billed_amount), 2) AS billed_amount,

    ROUND(
        100.0 * SUM(f.billed_amount)
        / NULLIF(
            SUM(SUM(f.billed_amount)) OVER (),
            0
        ),
        2
    ) AS billed_amount_share_pct

FROM analytics.fact_order_lines_star f

LEFT JOIN analytics.dim_product d
    ON f.product_key = d.product_key

WHERE f.account_type = 'CUSTOMER'

GROUP BY
    f.product_id,
    d.product_name,
    d.category;


-- ============================================================
-- 7. CUSTOMER KPI VIEW
-- ============================================================

CREATE VIEW analytics.v_kpi_customer AS
SELECT

    customer_id,

    COUNT(*) AS total_orders,

    MIN(order_datetime) AS first_order_datetime,

    MAX(order_datetime) AS last_order_datetime,

    SUM(total_quantity) AS total_units,

    ROUND(SUM(gross_amount), 2) AS gross_sales,

    ROUND(SUM(discount_amount), 2) AS total_discount,

    ROUND(SUM(net_amount), 2) AS net_sales,

    ROUND(SUM(billed_amount), 2) AS billed_amount,

    ROUND(
        SUM(billed_amount)
        / NULLIF(COUNT(*), 0),
        2
    ) AS customer_aov,

    ROUND(
        AVG(delivery_minutes)
        FILTER (
            WHERE order_status = 'DELIVERED'
        ),
        2
    ) AS avg_delivery_minutes,

    ROUND(
        AVG(avg_csat_score)
        FILTER (
            WHERE order_status = 'DELIVERED'
            AND avg_csat_score IS NOT NULL
        ),
        2
    ) AS avg_csat,

    SUM(support_ticket_count) AS support_tickets,

    CASE
        WHEN COUNT(*) > 1 THEN TRUE
        ELSE FALSE
    END AS is_repeat_customer

FROM analytics.fact_orders

WHERE account_type = 'CUSTOMER'

GROUP BY customer_id;


-- ============================================================
-- 8. OPERATIONS KPI VIEW
-- ============================================================

CREATE VIEW analytics.v_kpi_operations AS
SELECT

    order_status,

    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE delivery_datetime IS NOT NULL
    ) AS orders_with_delivery,

    ROUND(
        AVG(delivery_minutes),
        2
    ) AS avg_delivery_minutes,

    ROUND(
        AVG(sla_minutes),
        2
    ) AS avg_sla_minutes,

    COUNT(*) FILTER (
        WHERE sla_breached = TRUE
    ) AS sla_breached_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE sla_breached = TRUE
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE delivery_datetime IS NOT NULL
            ),
            0
        ),
        2
    ) AS sla_breach_rate_pct,

    ROUND(
        AVG(avg_csat_score)
        FILTER (
            WHERE avg_csat_score IS NOT NULL
        ),
        2
    ) AS avg_csat,

    SUM(support_ticket_count) AS support_tickets

FROM analytics.fact_orders

WHERE account_type = 'CUSTOMER'

GROUP BY order_status;


-- ============================================================
-- 9. KPI VALIDATION
-- ============================================================

-- Overall KPI
SELECT *
FROM analytics.v_kpi_overall;


-- Monthly KPI
SELECT *
FROM analytics.v_kpi_monthly
ORDER BY month_start;


-- City KPI
SELECT *
FROM analytics.v_kpi_city
ORDER BY billed_amount DESC;


-- Store KPI
SELECT *
FROM analytics.v_kpi_store
ORDER BY billed_amount DESC
LIMIT 10;


-- Category KPI
SELECT *
FROM analytics.v_kpi_category
ORDER BY billed_amount DESC;


-- Product KPI
SELECT *
FROM analytics.v_kpi_product
ORDER BY billed_amount DESC
LIMIT 10;


-- Customer KPI
SELECT *
FROM analytics.v_kpi_customer
ORDER BY billed_amount DESC
LIMIT 10;


-- Operations KPI
SELECT *
FROM analytics.v_kpi_operations
ORDER BY order_status;


-- ============================================================
-- 10. CORE RECONCILIATION CHECKS
-- ============================================================

-- Total billed amount must reconcile with fact_orders
SELECT
    ROUND(
        (
            SELECT SUM(billed_amount)
            FROM analytics.fact_orders
            WHERE account_type = 'CUSTOMER'
        ),
        2
    ) AS source_billed_amount,

    ROUND(
        (
            SELECT billed_amount
            FROM analytics.v_kpi_overall
        ),
        2
    ) AS kpi_billed_amount;


-- Total orders must reconcile
SELECT
    (
        SELECT COUNT(*)
        FROM analytics.fact_orders
        WHERE account_type = 'CUSTOMER'
    ) AS source_orders,

    (
        SELECT total_orders
        FROM analytics.v_kpi_overall
    ) AS kpi_orders;


-- Delivered orders must reconcile
SELECT
    (
        SELECT COUNT(*)
        FROM analytics.fact_orders
        WHERE account_type = 'CUSTOMER'
          AND order_status = 'DELIVERED'
    ) AS source_delivered_orders,

    (
        SELECT delivered_orders
        FROM analytics.v_kpi_overall
    ) AS kpi_delivered_orders;