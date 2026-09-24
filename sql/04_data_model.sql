-- ============================================================
-- SNAPBASKET ANALYTICS
-- 04 - ANALYTICAL DATA MODEL
-- ============================================================

DROP TABLE IF EXISTS analytics.fact_order_lines;

CREATE TABLE analytics.fact_order_lines AS

WITH order_line_counts AS (
    SELECT
        order_id,
        COUNT(*) AS line_item_count
    FROM analytics.stg_snapbasket_orders
    GROUP BY order_id
)

SELECT
    s.line_item_id,
    s.order_id,

    -- Date/time
    TO_TIMESTAMP(
        s.order_datetime,
        'DD/MM/YYYY HH24:MI'
    ) AS order_datetime,

    TO_TIMESTAMP(
        s.delivery_datetime,
        'DD/MM/YYYY HH24:MI'
    ) AS delivery_datetime,

    -- Order
    s.order_status,

    -- Customer
    s.customer_id,
    s.account_type,
    s.customer_city,

    -- Store
    s.store_id,
    s.store_city,
    s.store_type,

    -- Product
    s.product_id,
    s.product_name,
    s.category,

    -- Quantity
    CAST(s.quantity AS INTEGER) AS quantity,

    -- Pricing
    CAST(s.unit_price AS NUMERIC(12,2)) AS unit_price,

    CAST(s.gross_amount AS NUMERIC(12,2)) AS gross_amount,

    CAST(s.discount_amount AS NUMERIC(12,2)) AS discount_amount,

    CAST(s.net_amount AS NUMERIC(12,2)) AS net_amount,

    -- Fees
    CAST(s.delivery_fee AS NUMERIC(12,2)) AS order_delivery_fee,

    ROUND(
        CAST(s.delivery_fee AS NUMERIC)
        / o.line_item_count,
        2
    ) AS allocated_delivery_fee,

    CAST(s.packaging_fee AS NUMERIC(12,2)) AS packaging_fee,

    -- Billing
    CAST(s.billed_amount AS NUMERIC(12,2)) AS billed_amount,

    -- Operational
    s.payment_method,
    s.delivery_partner_id,

    CAST(s.delivery_minutes AS NUMERIC(10,2))
        AS delivery_minutes,

    CAST(s.sla_minutes AS INTEGER)
        AS sla_minutes,

    CASE
        WHEN CAST(s.delivery_minutes AS NUMERIC)
             > CAST(s.sla_minutes AS NUMERIC)
        THEN TRUE
        ELSE FALSE
    END AS sla_breached,

    -- Customer experience
    s.support_ticket_id,
    s.ticket_category,

    CAST(
        NULLIF(TRIM(s.csat_score), '')
        AS NUMERIC(3,1)
    ) AS csat_score,

    -- Order structure
    o.line_item_count

FROM analytics.stg_snapbasket_orders s

JOIN order_line_counts o
    ON s.order_id = o.order_id;

ALTER TABLE analytics.fact_order_lines
ADD PRIMARY KEY (line_item_id);