-- ============================================================
-- SNAPBASKET ANALYTICS
-- 10_insight_layer.sql
-- Insight Layer & Management Diagnostics
-- Population: CUSTOMER only
--
-- Purpose:
-- Convert validated KPI and driver analysis into
-- concise, decision-oriented analytical outputs.
--
-- IMPORTANT:
-- These outputs describe observed patterns and associations.
-- They do not establish causality.
-- ============================================================


-- ============================================================
-- I01. Commercial Trend Insight
-- Purpose: Identify monthly billed-value movement.
-- ============================================================

WITH monthly AS (
    SELECT
        month,
        billed_amount,
        LAG(billed_amount) OVER (
            ORDER BY month
        ) AS previous_billed
    FROM analytics.v_kpi_monthly
)

SELECT
    month,
    ROUND(billed_amount, 2) AS billed_amount,
    ROUND(
        billed_amount - previous_billed,
        2
    ) AS absolute_change,
    ROUND(
        (
            billed_amount - previous_billed
        )
        / NULLIF(previous_billed, 0) * 100,
        2
    ) AS growth_pct
FROM monthly
ORDER BY month;


-- ============================================================
-- I02. Geographic Concentration Insight
-- Purpose: Quantify concentration of billed amount by city.
-- ============================================================

WITH city_ranked AS (
    SELECT
        city,
        billed_amount,
        RANK() OVER (
            ORDER BY billed_amount DESC
        ) AS city_rank,
        SUM(billed_amount) OVER (
            ORDER BY billed_amount DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS cumulative_billed
    FROM analytics.v_kpi_city
)

SELECT
    city_rank,
    city,
    ROUND(billed_amount, 2) AS billed_amount,
    ROUND(
        billed_amount
        / SUM(billed_amount) OVER () * 100,
        2
    ) AS billed_share_pct,
    ROUND(
        cumulative_billed
        / SUM(billed_amount) OVER () * 100,
        2
    ) AS cumulative_share_pct
FROM city_ranked
ORDER BY city_rank;


-- ============================================================
-- I03. Operational Risk Insight
-- Purpose: Identify cities with elevated cancellation,
--          return and delivery metrics.
-- Minimum volume = 100 orders.
-- ============================================================

SELECT
    f.customer_city AS city,
    COUNT(*) AS total_orders,

    ROUND(
        SUM(f.billed_amount),
        2
    ) AS billed_amount,

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

ORDER BY
    cancellation_rate_pct DESC,
    return_rate_pct DESC;


-- ============================================================
-- I04. SLA → Customer Experience Signal
-- Purpose: Quantify differences between SLA-met and
--          SLA-breached delivered orders.
-- ============================================================

WITH sla_groups AS (
    SELECT
        CASE
            WHEN sla_breached
                THEN 'SLA Breached'
            ELSE 'SLA Met'
        END AS sla_status,

        COUNT(*) AS orders,

        AVG(delivery_minutes) AS avg_delivery_minutes,

        AVG(avg_csat_score) AS avg_csat

    FROM analytics.fact_orders

    WHERE account_type = 'CUSTOMER'
      AND order_status = 'DELIVERED'
      AND avg_csat_score IS NOT NULL

    GROUP BY sla_breached
),

comparison AS (
    SELECT
        MAX(
            avg_delivery_minutes
        ) FILTER (
            WHERE sla_status = 'SLA Breached'
        ) AS breached_delivery,

        MAX(
            avg_delivery_minutes
        ) FILTER (
            WHERE sla_status = 'SLA Met'
        ) AS met_delivery,

        MAX(
            avg_csat
        ) FILTER (
            WHERE sla_status = 'SLA Breached'
        ) AS breached_csat,

        MAX(
            avg_csat
        ) FILTER (
            WHERE sla_status = 'SLA Met'
        ) AS met_csat

    FROM sla_groups
)

SELECT
    g.sla_status,
    g.orders,
    ROUND(
        g.avg_delivery_minutes,
        2
    ) AS avg_delivery_minutes,
    ROUND(
        g.avg_csat,
        2
    ) AS avg_csat,

    ROUND(
        g.avg_delivery_minutes
        - c.met_delivery,
        2
    ) AS delivery_gap_vs_sla_met,

    ROUND(
        g.avg_csat
        - c.met_csat,
        2
    ) AS csat_gap_vs_sla_met

FROM sla_groups g
CROSS JOIN comparison c

ORDER BY
    CASE
        WHEN g.sla_status = 'SLA Breached'
            THEN 1
        ELSE 2
    END;


-- ============================================================
-- I05. Return Diagnostic
-- Purpose: Compare returned and delivered orders.
-- ============================================================

WITH status_groups AS (
    SELECT
        order_status,
        COUNT(*) AS orders,
        AVG(delivery_minutes) AS avg_delivery,
        AVG(avg_csat_score) AS avg_csat,
        AVG(
            delivery_minutes - sla_minutes
        ) AS avg_over_sla
    FROM analytics.fact_orders
    WHERE account_type = 'CUSTOMER'
      AND order_status IN (
          'DELIVERED',
          'RETURNED'
      )
    GROUP BY order_status
)

SELECT
    order_status,
    orders,
    ROUND(avg_delivery, 2)
        AS avg_delivery_minutes,
    ROUND(avg_csat, 2)
        AS avg_csat,
    ROUND(avg_over_sla, 2)
        AS avg_minutes_over_sla
FROM status_groups
ORDER BY
    CASE
        WHEN order_status = 'RETURNED'
            THEN 1
        ELSE 2
    END;


-- ============================================================
-- I06. Support Ticket Signal
-- Purpose: Compare orders with and without support tickets.
-- ============================================================

SELECT
    CASE
        WHEN support_ticket_count > 0
            THEN 'With Support Ticket'
        ELSE 'No Support Ticket'
    END AS support_status,

    COUNT(*) AS orders,

    ROUND(
        AVG(avg_csat_score),
        2
    ) AS avg_csat,

    ROUND(
        AVG(delivery_minutes)
        FILTER (
            WHERE delivery_minutes IS NOT NULL
        ),
        2
    ) AS avg_delivery_minutes

FROM analytics.fact_orders

WHERE account_type = 'CUSTOMER'
  AND avg_csat_score IS NOT NULL

GROUP BY
    CASE
        WHEN support_ticket_count > 0
            THEN 'With Support Ticket'
        ELSE 'No Support Ticket'
    END

ORDER BY support_status;


-- ============================================================
-- I07. Store Exception Analysis
-- Purpose: Identify active stores with elevated operational
--          indicators.
-- Minimum volume = 50 orders.
-- ============================================================

SELECT
    store_id,
    store_city,
    store_type,
    total_orders,
    ROUND(billed_amount, 2)
        AS billed_amount,
    ROUND(avg_delivery_minutes, 2)
        AS avg_delivery_minutes,
    ROUND(avg_csat, 2)
        AS avg_csat,
    ROUND(cancellation_rate_pct, 2)
        AS cancellation_rate_pct,
    returned_orders
FROM analytics.v_kpi_store
WHERE total_orders >= 50
ORDER BY
    avg_delivery_minutes DESC;


-- ============================================================
-- I08. Category Concentration
-- Purpose: Identify categories contributing most to
--          billed amount.
-- ============================================================

SELECT
    category,
    total_orders,
    total_units,
    ROUND(
        billed_amount,
        2
    ) AS billed_amount,

    ROUND(
        billed_amount
        / SUM(billed_amount) OVER () * 100,
        2
    ) AS billed_share_pct,

    ROUND(
        total_discount
        / NULLIF(gross_sales, 0) * 100,
        2
    ) AS discount_rate_pct

FROM analytics.v_kpi_category

ORDER BY billed_amount DESC;


-- ============================================================
-- I09. Product Concentration
-- Purpose: Quantify concentration of billed amount among
--          leading products.
-- ============================================================

WITH ranked_products AS (
    SELECT
        product_name,
        category,
        billed_amount,

        RANK() OVER (
            ORDER BY billed_amount DESC
        ) AS product_rank,

        SUM(billed_amount) OVER (
            ORDER BY billed_amount DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS cumulative_billed,

        SUM(billed_amount) OVER () AS total_billed

    FROM analytics.v_kpi_product
)

SELECT
    product_rank,
    product_name,
    category,

    ROUND(
        billed_amount,
        2
    ) AS billed_amount,

    ROUND(
        billed_amount
        / NULLIF(total_billed, 0) * 100,
        2
    ) AS billed_share_pct,

    ROUND(
        cumulative_billed
        / NULLIF(total_billed, 0) * 100,
        2
    ) AS cumulative_share_pct

FROM ranked_products

WHERE product_rank <= 20

ORDER BY product_rank;


-- ============================================================
-- I10. Customer Concentration & Repeat Economics
-- Purpose: Examine customer concentration and repeat behavior.
-- ============================================================

SELECT
    CASE
        WHEN total_orders > 1
            THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS customer_type,

    COUNT(*) AS customers,

    SUM(total_orders)
        AS total_orders,

    ROUND(
        SUM(billed_amount),
        2
    ) AS billed_amount,

    ROUND(
        AVG(billed_amount),
        2
    ) AS avg_customer_billed_amount,

    ROUND(
        AVG(total_orders),
        2
    ) AS avg_orders_per_customer

FROM analytics.v_kpi_customer

GROUP BY
    CASE
        WHEN total_orders > 1
            THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END

ORDER BY customer_type;


-- ============================================================
-- I11. Discount Dependency
-- Purpose: Identify categories where discounting is relatively
--          significant compared with gross sales.
-- ============================================================

SELECT
    category,

    ROUND(
        gross_sales,
        2
    ) AS gross_sales,

    ROUND(
        total_discount,
        2
    ) AS total_discount,

    ROUND(
        total_discount
        / NULLIF(gross_sales, 0) * 100,
        2
    ) AS discount_rate_pct,

    ROUND(
        billed_amount,
        2
    ) AS billed_amount

FROM analytics.v_kpi_category

ORDER BY discount_rate_pct DESC;


-- ============================================================
-- I12. Executive Insight Snapshot
-- Purpose: Provide a compact management-level KPI snapshot.
-- ============================================================

SELECT
    'Billed Amount' AS metric,
    ROUND(
        billed_amount,
        2
    )::numeric AS value
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Billed AOV',
    ROUND(
        billed_amount
        / NULLIF(total_orders, 0),
        2
    )
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Total Orders',
    total_orders::numeric
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Delivered Orders',
    delivered_orders::numeric
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
    SUM(
        CASE
            WHEN total_orders > 1
                THEN billed_amount
            ELSE 0
        END
    )
    / SUM(billed_amount) * 100
FROM analytics.v_kpi_customer;