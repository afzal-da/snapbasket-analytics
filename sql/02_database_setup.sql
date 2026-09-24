--SnapBasket Analytics
--PostgreSQL Database Setup

CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.raw_snapbasket_orders;

CREATE TABLE analytics.raw_snapbasket_orders (
    line_item_id            TEXT PRIMARY KEY,
    order_id                TEXT NOT NULL,
    order_datetime          TIMESTAMP NOT NULL,
    delivery_datetime       TIMESTAMP NOT NULL,
    order_status            TEXT NOT NULL,
    customer_id             TEXT NOT NULL,
    account_type            TEXT NOT NULL,
    customer_city           TEXT NOT NULL,
    store_id                TEXT NOT NULL,
    store_city              TEXT NOT NULL,
    product_id              TEXT NOT NULL,
    product_name            TEXT NOT NULL,
    category                TEXT NOT NULL,
    quantity                INTEGER NOT NULL,
    unit_price              NUMERIC(12, 2) NOT NULL,
    gross_amount            NUMERIC(12, 2) NOT NULL,
    discount_amount         NUMERIC(12, 2) NOT NULL,
    net_amount              NUMERIC(12, 2) NOT NULL,
    delivery_fee            NUMERIC(12, 2) NOT NULL,
    packaging_fee           NUMERIC(12, 2) NOT NULL,
    billed_amount           NUMERIC(12, 2) NOT NULL,
    payment_method          TEXT NOT NULL,
    delivery_partner_id     TEXT,
    delivery_minutes        NUMERIC(10, 2),
    sla_minutes             NUMERIC(10, 2),
    support_ticket_id       TEXT,
    ticket_category         TEXT,
    csat_score               NUMERIC(3, 1)
);