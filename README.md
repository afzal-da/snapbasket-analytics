cd ~/SnapBasket-Analytics

cat > README.md <<'EOF'
# SnapBasket Analytics

End-to-end Business Intelligence and Decision Analytics project built using PostgreSQL and Power BI to transform transactional grocery-order data into actionable commercial and operational insights.

## Project Overview

SnapBasket Analytics analyzes grocery e-commerce orders across customers, products, stores, cities, delivery operations, payments, discounts, customer satisfaction, and service-level performance.

The project follows a production-oriented analytical workflow:

Raw Data → Data Quality → Staging → Dimensional Modeling → Star Schema → KPI Layer → Driver Analysis → Insight Layer → Power BI

The objective is not only to report what happened, but to identify the commercial and operational drivers behind business performance.

## Business Objectives

The analysis addresses questions across five major areas:

### Commercial Performance
- What is the total billed revenue?
- How does billed revenue change over time?
- Which cities contribute the most revenue?
- Which product categories drive revenue?
- Which products have the highest revenue concentration?
- How dependent is revenue on discounts?

### Customer Analytics
- Which customers generate the most revenue?
- What proportion of revenue comes from repeat customers?
- How do repeat and one-time customers differ economically?
- How does customer support activity relate to customer satisfaction?

### Store & Operational Performance
- Which stores generate the highest commercial value?
- Which stores experience the highest cancellation and return rates?
- Which stores have significant SLA exposure?
- How does delivery time compare with SLA requirements?

### Delivery & Service Quality
- What percentage of delivered orders breach SLA?
- Which cities and stores have higher operational risk?
- How does SLA performance relate to CSAT?
- How do support tickets relate to delivery performance and customer satisfaction?

### Management Decision Support
- Where is revenue concentrated?
- Where is operational risk concentrated?
- Which commercial drivers require management attention?
- Which customer and product segments have the greatest economic significance?

## Technology Stack

| Layer | Technology |
|---|---|
| Data Source | CSV |
| Database | PostgreSQL 18 |
| Data Transformation | SQL |
| Data Modeling | Dimensional Modeling / Star Schema |
| Analytics | PostgreSQL SQL |
| Visualization | Microsoft Power BI |
| Version Control | Git / GitHub |
| Development Environment | macOS + PostgreSQL |
| BI Environment | Windows + Power BI Desktop |

## Analytical Architecture

```text
                    SnapBasket Orders
                           │
                           ▼
                  Raw Data Layer
                           │
                           ▼
                 Data Quality Checks
                           │
                           ▼
                    Staging Layer
                           │
                           ▼
                 Dimensional Modeling
                           │
                           ▼
                     Star Schema
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         Dimensions       Facts       Relationships
              │            │
              └────────────┼────────────┘
                           ▼
                       KPI Layer
                           │
                           ▼
                    Business Questions
                           │
                           ▼
                    Driver Analysis
                           │
                           ▼
                     Insight Layer
                           │
                           ▼
                      Power BI
                           │
                           ▼
                 Management Decisions