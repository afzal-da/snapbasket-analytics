# SnapBasket Analytics — Data Dictionary

## 1. Project Overview

**Project:** SnapBasket Analytics  
**Dataset:** `snapbasket_orders_2026.csv`  
**Period:** January 1, 2026 – June 30, 2026  
**Source Grain:** One row per order line item  
**Source Rows:** 8,826  
**Source Columns:** 29  
**Database:** PostgreSQL  
**Schema:** `analytics`

The project transforms raw transactional order-line data into a validated analytical warehouse and management decision-support model.

The analytical pipeline is:

```text
Raw CSV
   ↓
Staging Table
   ↓
Data Quality Validation
   ↓
Fact Order Lines
   ↓
Dimension Quality Validation
   ↓
Star Schema
   ↓
KPI Layer
   ↓
Business Questions
   ↓
Driver Analysis
   ↓
Insight Layer
   ↓
Power BI