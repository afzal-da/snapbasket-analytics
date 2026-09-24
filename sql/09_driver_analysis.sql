-- ============================================================
-- SNAPBASKET ANALYTICS
-- 09_driver_analysis.sql
-- Driver Analysis & Business Diagnostics
-- Population: CUSTOMER only
-- ============================================================


-- ============================================================
-- D01. Monthly Billed Amount Trend
-- Purpose: Identify changes in commercial performance.
-- ============================================================

SELECT
    month,
    billed_amount,
    LAG(billed_amount) OVER (ORDER BY month) AS previous_month_billed,
    ROUND(
        (
            billed_amount
            - LAG(billed_amount) OVER (ORDER BY month)
        )
        / NULLIF(LAG(billed_amount) OVER (ORDER BY month), 0)
        * 100,
        2
    ) AS mom_growth_pct
FROM analytics.v_kpi_monthly
ORDER BY month;


-- ============================================================
-- D02. City Commercial Concentration
-- Purpose: Measure how much billed amount is concentrated
--          in major customer cities.
-- ============================================================

WITH city_data AS (
    SELECT
        city,
        billed_amount
    FROM analytics.v_kpi_city
),
ranked AS (
    SELECT
        city,
        billed_amount,
        RANK() OVER (ORDER BY billed_amount DESC) AS city_rank,
        SUM(billed_amount) OVER (
            ORDER BY billed_amount DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_billed
    FROM city_data
)
SELECT
    city_rank,
    city,
    ROUND(billed_amount, 2) AS billed_amount,
    ROUND(
        billed_amount / SUM(billed_amount) OVER () * 100,
        2
    ) AS billed_share_pct,
    ROUND(
        cumulative_billed / SUM(billed_amount) OVER () * 100,
        2
    ) AS cumulative_billed_share_pct
FROM ranked
ORDER BY city_rank;


-- ============================================================
-- D03. City Operational Risk
-- Purpose: Compare volume with cancellation, return and
--          delivery performance.
-- Minimum volume threshold = 100 orders.
-- ============================================================

SELECT
    f.customer_city AS city,
    COUNT(*) AS total_orders,
    ROUND(SUM(f.billed_amount), 2) AS billed_amount,

    ROUND(
        COUNT(*) FILTER (
            WHERE f.order_status = 'CANCELLED'
        )::numeric
        / COUNT(*) * 100,
        2
    ) AS cancellation_rate_pct,

    ROUND(
        COUNT(*) FILTER (
            WHERE f.order_status = 'RETURNED'
        )::numeric
        / COUNT(*) * 100,
        2
    ) AS return_rate_pct,

    ROUND(
        AVG(f.delivery_minutes)
        FILTER (
            WHERE f.delivery_minutes IS NOT NULL
        ),
        2
    ) AS avg_delivery_minutes,

    ROUND(
        AVG(f.avg_csat_score)
        FILTER (
            WHERE f.avg_csat_score IS NOT NULL
        ),
        2
    ) AS avg_csat

FROM analytics.fact_orders f

WHERE f.account_type = 'CUSTOMER'

GROUP BY f.customer_city

HAVING COUNT(*) >= 100

ORDER BY cancellation_rate_pct DESC;


-- ============================================================
-- D04. City SLA Performance
-- Purpose: Identify cities where delivery performance differs.
-- ============================================================

SELECT
    city,
    total_orders,
    delivered_orders,
    avg_delivery_minutes,
    avg_csat
FROM analytics.v_kpi_city
WHERE delivered_orders >= 100
ORDER BY avg_delivery_minutes DESC;


-- ============================================================
-- D05. Store Operational Driver Analysis
-- Purpose: Identify stores with meaningful operational variation.
-- Minimum volume threshold = 50 orders.
-- ============================================================

SELECT
    store_id,
    store_city,
    store_type,
    total_orders,
    billed_amount,
    avg_delivery_minutes,
    avg_csat,
    cancellation_rate_pct,
    returned_orders
FROM analytics.v_kpi_store
WHERE total_orders >= 50
ORDER BY avg_delivery_minutes DESC;


-- ============================================================
-- D06. Store Cancellation Analysis
-- Purpose: Compare cancellation rates among sufficiently
--          active stores.
-- ============================================================

SELECT
    store_id,
    store_city,
    store_type,
    total_orders,
    cancelled_orders,
    cancellation_rate_pct,
    billed_amount
FROM analytics.v_kpi_store
WHERE total_orders >= 50
ORDER BY cancellation_rate_pct DESC;


-- ============================================================
-- D07. Store Return Analysis
-- Purpose: Compare return rates among sufficiently active stores.
-- Minimum volume threshold = 50 orders.
-- ============================================================

SELECT
    f.store_id,
    s.store_city,
    s.store_type,
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE f.order_status = 'RETURNED'
    ) AS returned_orders,

    ROUND(
        COUNT(*) FILTER (
            WHERE f.order_status = 'RETURNED'
        )::numeric
        / COUNT(*) * 100,
        2
    ) AS return_rate_pct,

    ROUND(
        AVG(f.delivery_minutes)
        FILTER (
            WHERE f.delivery_minutes IS NOT NULL
        ),
        2
    ) AS avg_delivery_minutes,

    ROUND(
        AVG(f.avg_csat_score)
        FILTER (
            WHERE f.avg_csat_score IS NOT NULL
        ),
        2
    ) AS avg_csat

FROM analytics.fact_orders f

JOIN analytics.dim_store s
    ON f.store_key = s.store_key

WHERE f.account_type = 'CUSTOMER'

GROUP BY
    f.store_id,
    s.store_city,
    s.store_type

HAVING COUNT(*) >= 50

ORDER BY return_rate_pct DESC;


-- ============================================================
-- D08. Delivery Time vs SLA
-- Purpose: Compare actual delivery time against SLA target.
-- ============================================================

SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(AVG(delivery_minutes), 2) AS avg_delivery_minutes,
    ROUND(AVG(sla_minutes), 2) AS avg_sla_minutes,
    ROUND(
        AVG(delivery_minutes - sla_minutes),
        2
    ) AS avg_minutes_over_sla
FROM analytics.fact_orders
WHERE account_type = 'CUSTOMER'
  AND delivery_minutes IS NOT NULL
GROUP BY order_status
ORDER BY avg_minutes_over_sla DESC;


-- ============================================================
-- D09. SLA Breach vs CSAT
-- Purpose: Determine whether SLA performance is associated
--          with customer satisfaction.
-- ============================================================

SELECT
    CASE
        WHEN sla_breached THEN 'SLA Breached'
        ELSE 'SLA Met'
    END AS sla_status,
    COUNT(*) AS orders,
    ROUND(AVG(delivery_minutes), 2) AS avg_delivery_minutes,
    ROUND(AVG(avg_csat_score), 2) AS avg_csat
FROM analytics.fact_orders
WHERE account_type = 'CUSTOMER'
  AND order_status = 'DELIVERED'
  AND avg_csat_score IS NOT NULL
GROUP BY sla_breached
ORDER BY sla_breached DESC;


-- ============================================================
-- D10. Returned vs Delivered Diagnostic
-- Purpose: Examine operational differences associated with
--          returned orders.
-- ============================================================

SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(AVG(delivery_minutes), 2) AS avg_delivery_minutes,
    ROUND(AVG(sla_minutes), 2) AS avg_sla_minutes,
    ROUND(AVG(avg_csat_score), 2) AS avg_csat,
    ROUND(
        AVG(delivery_minutes - sla_minutes),
        2
    ) AS avg_minutes_over_sla
FROM analytics.fact_orders
WHERE account_type = 'CUSTOMER'
  AND order_status IN ('DELIVERED', 'RETURNED')
GROUP BY order_status
ORDER BY order_status;


-- ============================================================
-- D11. Support Tickets vs CSAT
-- Purpose: Examine relationship between support interaction
--          and customer satisfaction.
-- ============================================================

SELECT
    support_ticket_count,
    COUNT(*) AS orders,
    ROUND(AVG(avg_csat_score), 2) AS avg_csat,
    ROUND(AVG(delivery_minutes), 2) AS avg_delivery_minutes
FROM analytics.fact_orders
WHERE account_type = 'CUSTOMER'
  AND avg_csat_score IS NOT NULL
GROUP BY support_ticket_count
ORDER BY support_ticket_count;


-- ============================================================
-- D12. Support Tickets vs Operational Outcomes
-- Purpose: Compare ticket incidence across order statuses.
-- ============================================================

SELECT
    order_status,
    COUNT(*) AS orders,
    SUM(
        CASE
            WHEN support_ticket_count > 0 THEN 1
            ELSE 0
        END
    ) AS orders_with_ticket,
    ROUND(
        SUM(
            CASE
                WHEN support_ticket_count > 0 THEN 1
                ELSE 0
            END
        )::numeric
        / COUNT(*) * 100,
        2
    ) AS ticket_incidence_pct
FROM analytics.fact_orders
WHERE account_type = 'CUSTOMER'
GROUP BY order_status
ORDER BY order_status;


-- ============================================================
-- D13. Category Commercial Driver Analysis
-- Purpose: Separate volume, discount and billing effects.
-- ============================================================

SELECT
    category,
    total_order_lines,
    total_orders,
    total_units,
    gross_sales,
    total_discount,
    net_sales,
    billed_amount,
    billed_amount_share_pct,
    ROUND(
        total_discount / NULLIF(gross_sales, 0) * 100,
        2
    ) AS discount_rate_pct
FROM analytics.v_kpi_category
ORDER BY billed_amount DESC;


-- ============================================================
-- D14. Product Concentration
-- Purpose: Identify products responsible for a large share
--          of billed amount.
-- ============================================================

SELECT
    product_rank,
    product_name,
    category,
    billed_amount,
    cumulative_billed_share_pct
FROM (
    SELECT
        RANK() OVER (ORDER BY billed_amount DESC) AS product_rank,
        product_name,
        category,
        billed_amount,
        SUM(billed_amount) OVER (
            ORDER BY billed_amount DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )
        / SUM(billed_amount) OVER ()
        * 100 AS cumulative_billed_share_pct
    FROM analytics.v_kpi_product
) x
WHERE product_rank <= 20
ORDER BY product_rank;


-- ============================================================
-- D15. Product Unit Economics Diagnostic
-- Purpose: Investigate products with unusually high billed
--          amounts relative to units sold.
-- ============================================================

SELECT
    product_id,
    product_name,
    category,
    units_sold,
    billed_amount,
    ROUND(
        billed_amount / NULLIF(units_sold, 0),
        2
    ) AS billed_per_unit,
    total_orders
FROM analytics.v_kpi_product
WHERE units_sold > 0
ORDER BY billed_per_unit DESC;


-- ============================================================
-- D16. High-Value Customer Concentration
-- Purpose: Measure concentration among customers by billed amount.
-- ============================================================

WITH customer_ranked AS (
    SELECT
        customer_id,
        billed_amount,
        RANK() OVER (
            ORDER BY billed_amount DESC
        ) AS customer_rank,
        SUM(billed_amount) OVER (
            ORDER BY billed_amount DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_billed
    FROM analytics.v_kpi_customer
)
SELECT
    customer_rank,
    customer_id,
    billed_amount,
    ROUND(
        billed_amount
        / SUM(billed_amount) OVER () * 100,
        2
    ) AS billed_share_pct,
    ROUND(
        cumulative_billed
        / SUM(billed_amount) OVER () * 100,
        2
    ) AS cumulative_billed_share_pct
FROM customer_ranked
WHERE customer_rank <= 20
ORDER BY customer_rank;


-- ============================================================
-- D17. Repeat Customer Economics
-- Purpose: Compare repeat vs one-time customer contribution.
-- ============================================================

SELECT
    CASE
        WHEN total_orders > 1 THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS customer_type,
    COUNT(*) AS customers,
    SUM(total_orders) AS total_orders,
    ROUND(SUM(billed_amount), 2) AS billed_amount,
    ROUND(AVG(billed_amount), 2) AS avg_customer_billed_amount,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer
FROM analytics.v_kpi_customer
GROUP BY
    CASE
        WHEN total_orders > 1 THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END
ORDER BY customer_type;


-- ============================================================
-- D18. Discount Dependency
-- Purpose: Identify categories where discounts represent a
--          relatively large proportion of gross sales.
-- ============================================================

SELECT
    category,
    gross_sales,
    total_discount,
    ROUND(
        total_discount / NULLIF(gross_sales, 0) * 100,
        2
    ) AS discount_rate_pct,
    billed_amount
FROM analytics.v_kpi_category
ORDER BY discount_rate_pct DESC;


-- ============================================================
-- D19. Payment Method Exposure
-- Purpose: Examine line-level payment-method exposure.
--
-- IMPORTANT:
-- An order may contain multiple payment methods.
-- Therefore orders_with_method are NOT mutually exclusive.
-- ============================================================

SELECT
    payment_method,
    COUNT(*) AS line_items,
    COUNT(DISTINCT order_id) AS orders_with_method,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(SUM(billed_amount), 2) AS billed_amount
FROM analytics.fact_order_lines_star
WHERE account_type = 'CUSTOMER'
GROUP BY payment_method
ORDER BY billed_amount DESC;


-- ============================================================
-- D20. City × Category Driver Matrix
-- Purpose: Identify category concentration inside cities.
-- ============================================================

SELECT
    f.customer_city AS city,
    p.category,
    COUNT(DISTINCT f.order_id) AS orders,
    SUM(f.quantity) AS units,
    ROUND(SUM(f.billed_amount), 2) AS billed_amount

FROM analytics.fact_order_lines_star f

JOIN analytics.dim_product p
    ON f.product_key = p.product_key

WHERE f.account_type = 'CUSTOMER'

GROUP BY
    f.customer_city,
    p.category

ORDER BY
    f.customer_city,
    billed_amount DESC;


-- ============================================================
-- D21. Executive Driver Summary
-- Purpose: Produce a compact diagnostic snapshot.
-- ============================================================

SELECT
    'Overall Billed Amount' AS metric,
    ROUND(billed_amount, 2)::numeric AS value
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Billed AOV',
    ROUND(billed_amount / NULLIF(total_orders, 0), 2)
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Cancellation Rate %',
    cancellation_rate_pct
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Return Rate %',
    return_rate_pct
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Delivered SLA Breach %',
    sla_breach_rate_pct
FROM analytics.v_kpi_operations
WHERE order_status = 'DELIVERED'

UNION ALL

SELECT
    'Delivered CSAT',
    delivered_avg_csat
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Repeat Customer Billed Share %',
    billed_amount_share_pct
FROM (
    SELECT
        billed_amount_share_pct
    FROM (
        SELECT
            SUM(
                CASE
                    WHEN total_orders > 1
                    THEN billed_amount
                    ELSE 0
                END
            )
            / SUM(billed_amount) * 100 AS billed_amount_share_pct
        FROM analytics.v_kpi_customer
    ) x
) y;