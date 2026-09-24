# SnapBasket Analytics — Analytical Decisions

## 1. Purpose

This document records the major analytical, data-modeling, and business-logic decisions made during development of the SnapBasket Analytics project.

The purpose is to make the analytical model:

- Explainable
- Reproducible
- Auditable
- Consistent across SQL and Power BI
- Defensible during technical interviews

The decisions documented here are based on data-quality testing and observed source-data behavior rather than assumptions about how the business system should have been designed.

---

# 2. Decision Summary

The major analytical decisions are:

| # | Decision | Reason |
|---|---|---|
| 1 | Treat source data as order-line grain | `line_item_id` is unique and orders contain multiple lines |
| 2 | Create separate order and line-item facts | Order and product/payment analytics have different grains |
| 3 | Keep customer city transactional | Customers can appear with different cities |
| 4 | Keep account type transactional | A small number of customers change account type |
| 5 | Keep payment method at line level | Orders can contain multiple payment methods |
| 6 | Do not create a payment fact | No payment transaction ID or independent payment amount exists |
| 7 | Use order-level CSAT | Repeated line-level CSAT values represent the same order response |
| 8 | Allocate delivery fee across lines | Source delivery fee is order-level and repeated across lines |
| 9 | Exclude `INTERNAL_TEST` from default commercial KPIs | It is a separate non-default account population |
| 10 | Use Billed Amount instead of Revenue | Dataset semantics do not establish accounting revenue |
| 11 | Use CUSTOMER-only default KPIs | Provides a consistent commercial population |
| 12 | Apply volume context to rates | Small populations can produce unstable percentages |
| 13 | Treat relationships as associations | No causal research design was performed |

---

# 3. Source Grain Decision

## Decision

The source dataset is treated as:

```text
1 row = 1 order line item