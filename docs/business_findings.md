# SnapBasket Analytics — Business Findings

## 1. Executive Summary

This analysis covers SnapBasket transactional activity from January 1, 2026 through June 30, 2026.

The default commercial population is `CUSTOMER`. `INTERNAL_TEST` records are retained in the warehouse but excluded from the primary commercial analysis.

During the six-month period, the CUSTOMER population generated:

- **2,928 orders**
- **750 customers**
- **₹20.80 lakh billed amount**
- **₹710.29 billed AOV**
- **12,306 units**
- **87.36% delivery completion**
- **4.88% cancellation rate**
- **5.53% return rate**
- **70.56% delivered-order SLA breach rate**
- **4.00 / 5 delivered CSAT**

The analysis identifies several important patterns:

1. Billed activity declined through May before recovering strongly in June.
2. Billed value is concentrated across a relatively small number of cities and products.
3. Repeat customers account for almost all CUSTOMER billed value during the six-month period.
4. SLA performance shows a substantial volume of delivered orders exceeding the stated SLA.
5. Returned orders have longer average delivery times and lower CSAT than delivered orders.
6. Orders with support tickets show lower average CSAT and longer delivery times than orders without tickets.
7. Operational performance varies materially across cities and stores.
8. Product and customer concentration should be monitored as descriptive characteristics of the current business mix.

These findings describe observed patterns in the dataset. They do not establish causality.

---

# 2. Commercial Performance

## Finding 1 — Six-Month Billed Activity

The CUSTOMER population generated:

| Metric | Value |
|---|---:|
| Orders | 2,928 |
| Customers | 750 |
| Gross Amount | ₹21.53 lakh |
| Discount Amount | ₹1.59 lakh |
| Net Amount | ₹19.94 lakh |
| Billed Amount | ₹20.80 lakh |
| Billed AOV | ₹710.29 |

The billed amount represents customer charges captured by the analytical dataset.

It is intentionally described as **Billed Amount** rather than accounting revenue because the dataset does not establish formal revenue-recognition semantics.

---

# 3. Monthly Commercial Trend

Monthly CUSTOMER billed amount was:

| Month | Billed Amount | MoM Growth |
|---|---:|---:|
| Jan 2026 | ₹355,172.21 | N/A |
| Feb 2026 | ₹362,644.40 | +2.10% |
| Mar 2026 | ₹351,398.95 | -3.10% |
| Apr 2026 | ₹340,370.64 | -3.14% |
| May 2026 | ₹311,011.02 | -8.63% |
| Jun 2026 | ₹359,117.28 | +15.47% |

### Observation

Billed amount declined from February through May.

May recorded the lowest monthly billed amount at:

**₹311,011.02**

June then increased by:

**15.47% month over month**

to:

**₹359,117.28**

### Interpretation

The dataset therefore shows a period of declining billed activity followed by a strong June recovery.

The dataset alone does not establish the underlying business cause of this movement.

Potential explanations would require additional information such as:

- customer acquisition
- marketing activity
- product availability
- pricing changes
- seasonality
- store operations
- promotions
- stock-outs

---

# 4. City Concentration

CUSTOMER billed amount by city:

| City | Billed Amount | Billed Share |
|---|---:|---:|
| Bengaluru | ₹547,565.21 | 26.33% |
| Mumbai | ₹341,749.37 | 16.43% |
| Delhi | ₹300,937.45 | 14.47% |
| Hyderabad | ₹198,553.17 | 9.55% |
| Pune | ₹173,771.65 | 8.36% |
| Kolkata | ₹120,226.28 | 5.78% |
| Ahmedabad | ₹102,010.57 | 4.91% |
| Chennai | ₹99,150.22 | 4.77% |
| Jaipur | ₹80,467.68 | 3.87% |
| Lucknow | ₹57,299.22 | 2.76% |
| Indore | ₹29,266.21 | 1.41% |
| Kochi | ₹28,717.47 | 1.38% |

### Observation

Bengaluru is the largest CUSTOMER billed-value city in the dataset.

Its billed amount is:

**₹547,565.21**

representing:

**26.33%**

of CUSTOMER billed amount.

The next two cities are Mumbai and Delhi.

Together:

```text
Bengaluru + Mumbai + Delhi
=
57.23% of CUSTOMER billed amount