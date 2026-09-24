# SnapBasket Analytics — Data Model

## 1. Purpose

This document describes the analytical data model used for the SnapBasket Analytics project.

The model transforms raw transactional order-line data into a validated PostgreSQL star schema that supports:

- Commercial analysis
- Order analysis
- Customer analysis
- Product analysis
- Category analysis
- Store analysis
- Delivery operations
- SLA analysis
- Customer experience analysis
- Support analysis
- Payment-method exposure
- Power BI reporting

The model separates data according to its analytical grain so that measures can be calculated without unnecessary duplication or double counting.

---

# 2. Overall Architecture

The complete analytical architecture is:

```text
                         SOURCE
                           │
                           ▼
              snapbasket_orders_2026.csv
                           │
                           ▼
                    STAGING LAYER
                           │
                           ▼
              Data Quality Validation
                           │
                           ▼
                  TRANSFORMATION LAYER
                           │
                           ▼
                  fact_order_lines
                           │
                           ▼
                 DIMENSION QUALITY
                           │
                           ▼
                    STAR SCHEMA
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
       fact_orders              fact_order_lines_star
             │                           │
             └─────────────┬─────────────┘
                           │
                           ▼
                     KPI LAYER
                           │
                           ▼
                 BUSINESS QUESTIONS
                           │
                           ▼
                   DRIVER ANALYSIS
                           │
                           ▼
                   INSIGHT LAYER
                           │
                           ▼
                       POWER BI