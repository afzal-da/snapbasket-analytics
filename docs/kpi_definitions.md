# SnapBasket Analytics — KPI Definitions

## 1. Purpose

This document defines the official business metrics used throughout the SnapBasket Analytics project.

These definitions are the single source of truth for:

- PostgreSQL KPI views
- Business-question analysis
- Driver analysis
- Insight layer
- Power BI dashboards
- Management reporting
- README documentation
- Portfolio case study
- Interview discussions

The same KPI must use the same definition across all analytical layers.

---

# 2. Reporting Scope

## Analysis Period

**January 1, 2026 – June 30, 2026**

## Default Commercial Population

```sql
account_type = 'CUSTOMER'