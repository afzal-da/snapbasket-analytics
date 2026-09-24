-- ============================================================
-- SnapBasket Analytics
-- 08_business_questions.sql
-- Purpose: Business analysis / decision-support queries
-- Population: CUSTOMER
-- ============================================================


-- ============================================================
-- Q01. Overall Business Performance
-- ============================================================

SELECT
    total_orders,
    delivered_orders,
    returned_orders,
    cancelled_orders,
    pending_orders,
    total_customers,
    repeat_customers,
    gross_sales,
    total_discount,
    net_sales,
    billed_amount,
    total_units,
    avg_delivered_minutes,
    delivered_avg_csat,
    cancellation_rate_pct,
    return_rate_pct,
    discount_rate_pct,
    delivery_completion_rate_pct
FROM analytics.v_kpi_overall;


-- ============================================================
-- Q02. Monthly Business Performance
-- ============================================================

SELECT
    month,
    total_orders,
    delivered_orders,
    cancelled_orders,
    returned_orders,
    pending_orders,
    billed_amount,
    aov,
    avg_delivery_minutes,
    avg_csat,
    cancellation_rate_pct,
    return_rate_pct,
    sla_breach_rate_pct
FROM analytics.v_kpi_monthly
ORDER BY month_start;


-- ============================================================
-- Q03. Month with Highest Billed Amount
-- ============================================================

SELECT
    month,
    billed_amount,
    total_orders,
    aov
FROM analytics.v_kpi_monthly
ORDER BY billed_amount DESC
LIMIT 1;


-- ============================================================
-- Q04. Month with Lowest Billed Amount
-- ============================================================

SELECT
    month,
    billed_amount,
    total_orders,
    aov
FROM analytics.v_kpi_monthly
ORDER BY billed_amount
LIMIT 1;


-- ============================================================
-- Q05. Month-over-Month Billed Amount Growth
-- ============================================================

WITH monthly AS (

    SELECT
        month_start,
        month,
        billed_amount
    FROM analytics.v_kpi_monthly

)

SELECT
    month,
    billed_amount,

    LAG(billed_amount) OVER (
        ORDER BY month_start
    ) AS previous_month_billed_amount,

    ROUND(
        100.0 *
        (
            billed_amount
            - LAG(billed_amount) OVER (
                ORDER BY month_start
            )
        )
        / NULLIF(
            LAG(billed_amount) OVER (
                ORDER BY month_start
            ),
            0
        ),
        2
    ) AS mom_growth_pct

FROM monthly

ORDER BY month_start;


-- ============================================================
-- Q06. City Performance
-- ============================================================

SELECT
    city,
    total_orders,
    total_customers,
    delivered_orders,
    cancelled_orders,
    returned_orders,
    billed_amount,
    aov,
    avg_delivery_minutes,
    avg_csat,
    cancellation_rate_pct,
    return_rate_pct
FROM analytics.v_kpi_city
ORDER BY billed_amount DESC;


-- ============================================================
-- Q07. Highest Order-Volume City
-- ============================================================

SELECT
    city,
    total_orders
FROM analytics.v_kpi_city
ORDER BY total_orders DESC
LIMIT 1;


-- ============================================================
-- Q08. Highest Billed-Amount City
-- ============================================================

SELECT
    city,
    billed_amount,
    total_orders,
    aov
FROM analytics.v_kpi_city
ORDER BY billed_amount DESC
LIMIT 1;


-- ============================================================
-- Q09. Store Performance
-- ============================================================

SELECT
    store_id,
    store_city,
    store_type,
    total_orders,
    total_customers,
    delivered_orders,
    cancelled_orders,
    returned_orders,
    billed_amount,
    aov,
    avg_delivery_minutes,
    avg_csat,
    cancellation_rate_pct
FROM analytics.v_kpi_store
ORDER BY billed_amount DESC;


-- ============================================================
-- Q10. Top 10 Products by Billed Amount
-- ============================================================

SELECT
    product_id,
    product_name,
    category,
    total_orders,
    total_customers,
    units_sold,
    billed_amount,
    billed_amount_share_pct
FROM analytics.v_kpi_product
ORDER BY billed_amount DESC
LIMIT 10;


-- ============================================================
-- Q11. Top 10 Products by Units Sold
-- ============================================================

SELECT
    product_id,
    product_name,
    category,
    units_sold,
    total_orders,
    billed_amount
FROM analytics.v_kpi_product
ORDER BY units_sold DESC
LIMIT 10;


-- ============================================================
-- Q12. Category Performance
-- ============================================================

SELECT
    category,
    total_order_lines,
    total_orders,
    total_customers,
    total_units,
    gross_sales,
    total_discount,
    net_sales,
    billed_amount,
    billed_amount_share_pct
FROM analytics.v_kpi_category
ORDER BY billed_amount DESC;


-- ============================================================
-- Q13. Customer Concentration
-- ============================================================

SELECT
    COUNT(*) AS customers,

    COUNT(*) FILTER (
        WHERE is_repeat_customer = TRUE
    ) AS repeat_customers,

    COUNT(*) FILTER (
        WHERE is_repeat_customer = FALSE
    ) AS one_time_customers

FROM analytics.v_kpi_customer;


-- ============================================================
-- Q14. Top 20 Customers by Billed Amount
-- ============================================================

SELECT
    customer_id,
    total_orders,
    total_units,
    billed_amount,
    customer_aov,
    avg_delivery_minutes,
    avg_csat,
    support_tickets,
    is_repeat_customer
FROM analytics.v_kpi_customer
ORDER BY billed_amount DESC
LIMIT 20;


-- ============================================================
-- Q15. Repeat Customer Revenue Contribution
-- ============================================================

SELECT

    CASE
        WHEN is_repeat_customer = TRUE
        THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS customer_type,

    COUNT(*) AS customers,

    ROUND(
        SUM(billed_amount),
        2
    ) AS billed_amount,

    ROUND(
        AVG(billed_amount),
        2
    ) AS avg_customer_billed_amount,

    ROUND(
        100.0 * SUM(billed_amount)
        / SUM(SUM(billed_amount)) OVER (),
        2
    ) AS billed_amount_share_pct

FROM analytics.v_kpi_customer

GROUP BY
    is_repeat_customer

ORDER BY
    billed_amount DESC;


-- ============================================================
-- Q16. Operational Performance by Status
-- ============================================================

SELECT
    order_status,
    total_orders,
    orders_with_delivery,
    avg_delivery_minutes,
    avg_sla_minutes,
    sla_breached_orders,
    sla_breach_rate_pct,
    avg_csat,
    support_tickets
FROM analytics.v_kpi_operations
ORDER BY order_status;


-- ============================================================
-- Q17. Delivered Order SLA Performance
-- ============================================================

SELECT
    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE sla_breached = TRUE
    ) AS sla_breached_orders,

    COUNT(*) FILTER (
        WHERE sla_breached = FALSE
    ) AS sla_met_orders,

    ROUND(
        100.0 *
        COUNT(*) FILTER (
            WHERE sla_breached = TRUE
        )
        / COUNT(*),
        2
    ) AS sla_breach_rate_pct,

    ROUND(
        AVG(delivery_minutes),
        2
    ) AS avg_delivery_minutes

FROM analytics.fact_orders

WHERE account_type = 'CUSTOMER'
  AND order_status = 'DELIVERED';


-- ============================================================
-- Q18. Returned Orders vs Delivered Orders
-- ============================================================

SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(AVG(delivery_minutes), 2) AS avg_delivery_minutes,
    ROUND(AVG(avg_csat_score), 2) AS avg_csat,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS order_share_pct

FROM analytics.fact_orders

WHERE account_type = 'CUSTOMER'
  AND order_status IN ('DELIVERED', 'RETURNED')

GROUP BY order_status

ORDER BY order_status;


-- ============================================================
-- Q19. Payment Method Exposure
-- ============================================================

SELECT

    payment_method,

    COUNT(*) AS line_items,

    COUNT(DISTINCT order_id) AS orders_with_method,

    COUNT(DISTINCT customer_id) AS customers,

    ROUND(SUM(billed_amount), 2) AS billed_amount

FROM analytics.fact_order_lines_star

WHERE account_type = 'CUSTOMER'

GROUP BY
    payment_method

ORDER BY
    billed_amount DESC;


-- ============================================================
-- Q20. Customer City × Category Analysis
-- ============================================================

SELECT

    f.customer_city AS city,

    d.category,

    COUNT(DISTINCT f.order_id) AS orders,

    SUM(f.quantity) AS units,

    ROUND(SUM(f.billed_amount), 2) AS billed_amount

FROM analytics.fact_order_lines_star f

JOIN analytics.dim_product d
    ON f.product_key = d.product_key

WHERE f.account_type = 'CUSTOMER'

GROUP BY
    f.customer_city,
    d.category

ORDER BY
    f.customer_city,
    billed_amount DESC;


-- ============================================================
-- Q21. Top Product in Each Category
-- ============================================================

WITH ranked_products AS (

    SELECT

        product_id,
        product_name,
        category,
        billed_amount,

        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY billed_amount DESC
        ) AS category_rank

    FROM analytics.v_kpi_product

)

SELECT
    product_id,
    product_name,
    category,
    billed_amount
FROM ranked_products
WHERE category_rank = 1
ORDER BY billed_amount DESC;


-- ============================================================
-- Q22. Top 3 Products in Each Category
-- ============================================================

WITH ranked_products AS (

    SELECT

        product_id,
        product_name,
        category,
        billed_amount,

        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY billed_amount DESC
        ) AS category_rank

    FROM analytics.v_kpi_product

)

SELECT
    category_rank,
    category,
    product_id,
    product_name,
    billed_amount

FROM ranked_products

WHERE category_rank <= 3

ORDER BY
    category,
    category_rank;


-- ============================================================
-- Q23. City Cancellation Analysis
-- ============================================================

SELECT
    city,
    total_orders,
    cancelled_orders,
    cancellation_rate_pct,
    billed_amount
FROM analytics.v_kpi_city
ORDER BY cancellation_rate_pct DESC;


-- ============================================================
-- Q24. City Return Analysis
-- ============================================================

SELECT
    city,
    total_orders,
    returned_orders,
    return_rate_pct,
    billed_amount
FROM analytics.v_kpi_city
ORDER BY return_rate_pct DESC;


-- ============================================================
-- Q25. Revenue Concentration — Top 10 Products
-- ============================================================

WITH ranked_products AS (

    SELECT
        product_id,
        product_name,
        category,
        billed_amount,

        ROW_NUMBER() OVER (
            ORDER BY billed_amount DESC
        ) AS product_rank

    FROM analytics.v_kpi_product

),

total_business AS (

    SELECT
        SUM(billed_amount) AS total_billed_amount

    FROM analytics.v_kpi_product

),

top_products AS (

    SELECT
        product_rank,
        product_id,
        product_name,
        category,
        billed_amount

    FROM ranked_products

    WHERE product_rank <= 10

)

SELECT

    product_rank,
    product_id,
    product_name,
    category,
    billed_amount,

    ROUND(
        100.0 *
        SUM(billed_amount) OVER (
            ORDER BY product_rank
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        )
        / NULLIF(
            total_business.total_billed_amount,
            0
        ),
        2
    ) AS cumulative_billed_share_pct

FROM top_products

CROSS JOIN total_business

ORDER BY product_rank;


-- ============================================================
-- Q26. High-Value Customers
-- ============================================================

SELECT
    customer_id,
    total_orders,
    billed_amount,
    customer_aov,
    avg_csat,
    support_tickets
FROM analytics.v_kpi_customer
WHERE billed_amount >= 5000
ORDER BY billed_amount DESC;


-- ============================================================
-- Q27. Customers with High Support Ticket Activity
-- ============================================================

SELECT
    customer_id,
    total_orders,
    billed_amount,
    support_tickets,
    avg_csat
FROM analytics.v_kpi_customer
WHERE support_tickets > 0
ORDER BY support_tickets DESC, billed_amount DESC;


-- ============================================================
-- Q28. Discount Dependency by Category
-- ============================================================

SELECT

    category,

    gross_sales,

    total_discount,

    net_sales,

    ROUND(
        100.0 * total_discount
        / NULLIF(gross_sales, 0),
        2
    ) AS discount_rate_pct,

    billed_amount

FROM analytics.v_kpi_category

ORDER BY discount_rate_pct DESC;


-- ============================================================
-- Q29. Business KPI Summary for Reporting
-- ============================================================

SELECT

    'Orders' AS metric,
    total_orders::numeric AS value
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Delivered Orders',
    delivered_orders::numeric
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Customers',
    total_customers::numeric
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Repeat Customers',
    repeat_customers::numeric
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Gross Sales',
    gross_sales
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Net Sales',
    net_sales
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Billed Amount',
    billed_amount
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Billed AOV',
    billed_amount / NULLIF(total_orders, 0)
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Average Delivery Minutes',
    avg_delivered_minutes
FROM analytics.v_kpi_overall

UNION ALL

SELECT
    'Average Delivered CSAT',
    delivered_avg_csat
FROM analytics.v_kpi_overall;