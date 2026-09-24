-- ============================================================
-- SNAPBASKET ANALYTICS
-- 03 - DATA QUALITY AUDIT
-- ============================================================

-- ------------------------------------------------------------
-- 1. ROW COUNT
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows
FROM analytics.stg_snapbasket_orders;


-- ------------------------------------------------------------
-- 2. COLUMN COUNT
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_columns
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'stg_snapbasket_orders';


-- ------------------------------------------------------------
-- 3. DATE RANGE
-- Explicitly interpret source dates as DD/MM/YYYY
-- ------------------------------------------------------------

SELECT
    MIN(TO_TIMESTAMP(order_datetime, 'DD/MM/YYYY HH24:MI')) AS first_order,
    MAX(TO_TIMESTAMP(order_datetime, 'DD/MM/YYYY HH24:MI')) AS last_order
FROM analytics.stg_snapbasket_orders;


-- ------------------------------------------------------------
-- 4. ORDER STATUS DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    order_status,
    COUNT(*) AS line_items,
    COUNT(DISTINCT order_id) AS orders
FROM analytics.stg_snapbasket_orders
GROUP BY order_status
ORDER BY orders DESC;


-- ------------------------------------------------------------
-- 5. DUPLICATE LINE ITEM IDs
-- ------------------------------------------------------------

SELECT
    line_item_id,
    COUNT(*) AS occurrences
FROM analytics.stg_snapbasket_orders
GROUP BY line_item_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;


-- ------------------------------------------------------------
-- 6. ORDER LINE DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    order_id,
    COUNT(*) AS line_items
FROM analytics.stg_snapbasket_orders
GROUP BY order_id
ORDER BY line_items DESC
LIMIT 20;


-- ------------------------------------------------------------
-- 7. NULL / BLANK VALUE AUDIT
-- ------------------------------------------------------------

SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(line_item_id), '') IS NULL)
        AS missing_line_item_id,

    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_id), '') IS NULL)
        AS missing_order_id,

    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_id), '') IS NULL)
        AS missing_customer_id,

    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_id), '') IS NULL)
        AS missing_product_id,

    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_name), '') IS NULL)
        AS missing_product_name,

    COUNT(*) FILTER (WHERE NULLIF(TRIM(category), '') IS NULL)
        AS missing_category,

    COUNT(*) FILTER (WHERE NULLIF(TRIM(store_id), '') IS NULL)
        AS missing_store_id,

    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_city), '') IS NULL)
        AS missing_customer_city,

    COUNT(*) FILTER (WHERE NULLIF(TRIM(payment_method), '') IS NULL)
        AS missing_payment_method

FROM analytics.stg_snapbasket_orders;


-- ------------------------------------------------------------
-- 8. NUMERIC VALIDATION
-- ------------------------------------------------------------

SELECT
    COUNT(*) FILTER (
        WHERE CAST(quantity AS NUMERIC) <= 0
    ) AS invalid_quantity,

    COUNT(*) FILTER (
        WHERE CAST(unit_price AS NUMERIC) < 0
    ) AS negative_unit_price,

    COUNT(*) FILTER (
        WHERE CAST(gross_amount AS NUMERIC) < 0
    ) AS negative_gross_amount,

    COUNT(*) FILTER (
        WHERE CAST(discount_amount AS NUMERIC) < 0
    ) AS negative_discount,

    COUNT(*) FILTER (
        WHERE CAST(net_amount AS NUMERIC) < 0
    ) AS negative_net_amount

FROM analytics.stg_snapbasket_orders;


-- ------------------------------------------------------------
-- 9. GROSS AMOUNT RECONCILIATION
-- gross_amount = quantity × unit_price
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS gross_amount_mismatches
FROM analytics.stg_snapbasket_orders
WHERE ABS(
    CAST(gross_amount AS NUMERIC)
    -
    (
        CAST(quantity AS NUMERIC)
        * CAST(unit_price AS NUMERIC)
    )
) > 0.01;


-- ------------------------------------------------------------
-- 10. NET AMOUNT RECONCILIATION
-- net_amount = gross_amount - discount_amount
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS net_amount_mismatches
FROM analytics.stg_snapbasket_orders
WHERE ABS(
    CAST(net_amount AS NUMERIC)
    -
    (
        CAST(gross_amount AS NUMERIC)
        - CAST(discount_amount AS NUMERIC)
    )
) > 0.01;


-- ------------------------------------------------------------
-- 11. BILLING RECONCILIATION
-- Do NOT assume the formula yet.
-- We are measuring the difference.
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS billing_mismatches,
    ROUND(
        AVG(
            CAST(billed_amount AS NUMERIC)
            -
            (
                CAST(net_amount AS NUMERIC)
                + CAST(delivery_fee AS NUMERIC)
                + CAST(packaging_fee AS NUMERIC)
            )
        ),
        2
    ) AS avg_billing_difference
FROM analytics.stg_snapbasket_orders;


-- ------------------------------------------------------------
-- 12. DELIVERY / SLA AUDIT
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE CAST(delivery_minutes AS NUMERIC)
              > CAST(sla_minutes AS NUMERIC)
    ) AS sla_breaches,

    ROUND(
        100.0 *
        COUNT(*) FILTER (
            WHERE CAST(delivery_minutes AS NUMERIC)
                  > CAST(sla_minutes AS NUMERIC)
        )
        / COUNT(*),
        2
    ) AS sla_breach_percentage

FROM analytics.stg_snapbasket_orders;


-- ------------------------------------------------------------
-- 13. CSAT AUDIT
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,

    COUNT(NULLIF(TRIM(csat_score), '')) AS rows_with_csat,

    ROUND(
        AVG(
            CAST(NULLIF(TRIM(csat_score), '') AS NUMERIC)
        ),
        2
    ) AS average_csat,

    MIN(
        CAST(NULLIF(TRIM(csat_score), '') AS NUMERIC)
    ) AS minimum_csat,

    MAX(
        CAST(NULLIF(TRIM(csat_score), '') AS NUMERIC)
    ) AS maximum_csat

FROM analytics.stg_snapbasket_orders;


-- ------------------------------------------------------------
-- 14. CUSTOMER CITY DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    customer_city,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(*) AS line_items
FROM analytics.stg_snapbasket_orders
GROUP BY customer_city
ORDER BY orders DESC;


-- ------------------------------------------------------------
-- 15. PRODUCT CATEGORY DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    category,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(*) AS line_items,
    ROUND(
        SUM(CAST(net_amount AS NUMERIC)),
        2
    ) AS net_revenue
FROM analytics.stg_snapbasket_orders
GROUP BY category
ORDER BY net_revenue DESC;


-- ------------------------------------------------------------
-- 16. PAYMENT METHOD DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    payment_method,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(
        SUM(CAST(billed_amount AS NUMERIC)),
        2
    ) AS billed_revenue
FROM analytics.stg_snapbasket_orders
GROUP BY payment_method
ORDER BY orders DESC;


-- ------------------------------------------------------------
-- 17. STORE DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    store_id,
    store_city,
    store_type,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(*) AS line_items
FROM analytics.stg_snapbasket_orders
GROUP BY
    store_id,
    store_city,
    store_type
ORDER BY orders DESC;