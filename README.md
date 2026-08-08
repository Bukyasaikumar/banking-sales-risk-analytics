# Banking Sales & Risk Analytics Dashboard

A messy banking sales dataset, cleaned and validated through a Bronze → Silver → Gold pipeline in MySQL, then reported on in Power BI — built to practice applying the same data validation thinking I use in EY audit engagements (invoice checks, PAN/GST format validation, duplicate detection) to a full data pipeline instead of doing it manually.

## The problem

Raw data from source systems is never clean. This dataset has region names spelled five different ways, product categories with typos, dates in six different formats depending on how each Excel cell was formatted, duplicate customer records, and invalid PAN/GST numbers. If a report gets built directly on top of data like this, it's wrong — and nobody notices until a decision gets made on bad numbers.

## The approach

Three layers, each with one job:

- **Bronze** — land the raw data exactly as it came in. Nothing changed. This is the record of what was actually received.
- **Silver** — clean and validate. Fix formatting, parse dates, validate PAN/GST, catch duplicates. Anything that fails is moved to a separate reject table with the reason, never silently deleted.
- **Gold** — the final, trustworthy tables, built only from validated data, ready for reporting.

One deliberate design choice throughout: **business validity and compliance validity are kept separate.** A sale isn't rejected just because a customer's PAN is formatted wrong — that's a documentation-completeness issue, not proof the sale didn't happen. This mirrors how an audit separates transaction testing from documentation completeness testing.

## What it found

- **223 of 387 valid sales transactions (~58%) have an invalid or missing PAN/GST** — a real, quantified compliance gap, not a footnote
- **A join fan-out bug**: an unresolved duplicate customer record caused one customer's sales to be silently double-counted in an early version of the Gold fact table (401 rows instead of the correct 387) — caught by reconciling row counts rather than assuming a join was correct
- **A scale mismatch between source sheets**: `Monthly_Targets` and `Sales_Transactions` were built on incompatible scales (average target ≈ ₹4.6L per rep/month vs. average transaction ≈ ₹28.7L) — actual-vs-target comparisons are not meaningful as a percentage. Documented as a known limitation on the dashboard rather than fabricated into a clean-looking but false number.
- **A completeness gap**: transactions exist for customer IDs that were never captured in the customer master table at all — real, valid sales with no matching customer record.

## Tech stack

MySQL 8 (data cleaning and modeling) → Power BI Desktop (live MySQL connection, star schema, DAX)

## Repo structure

```
sql/
  01_bronze_layer.sql              raw landing tables
  02_silver_sales.sql              sales: cleaning, validation, reject logic
  03_silver_customer.sql           customer: cleaning, validation, reject logic
  04_silver_targets_pricing.sql    targets & pricing: type-casting only (already clean)
  05_gold_fact_sales.sql           enriched fact table
  06_gold_sales_vs_target.sql      actual vs. target by rep/month
  07_gold_compliance_exceptions.sql PAN/GST exception report
power_bi/
  dax_measures.md                  data model, DAX measures, dashboard layout
dashboard_screenshot.png           full dashboard, for anyone without Power BI installed
```

## How to reproduce

1. Create a MySQL database named `banking_etl_project`
2. Run the SQL scripts in `sql/` in numeric order
3. Open Power BI Desktop → Get Data → MySQL database → point at your local instance → load the three `gold_*` tables
4. Follow `power_bi/dax_measures.md` for the data model and measures

## Known limitation

The `Target Achievement %` measure exists in the model but is intentionally not shown on the dashboard — see "What it found" above. Shown as reported, not adjusted.

## What I'd build next

A proper shared customer dimension linking the fact and exception tables, so exceptions could be broken down by customer risk rating without the many-to-many join risk. Currently avoided deliberately rather than built incorrectly.

---
Built by Sai Kumar — Risk Consulting, EY.
