# Power BI model

## Connection
Live connection from Power BI Desktop to MySQL (`localhost:3306`, database `banking_etl_project`) via the MySQL database connector, Import mode. Three Gold tables loaded: `gold_fact_sales`, `gold_sales_vs_target`, `gold_compliance_exceptions`.

## Data model — star schema
- **`gold_fact_sales`** — the one fact table
- **`DimDate`** — one dimension, related to `gold_fact_sales[txn_date]` (many-to-one, active)
- **`gold_sales_vs_target`** and **`gold_compliance_exceptions`** are deliberately left unrelated — each is a self-contained, pre-aggregated summary table with everything its own visuals need. An earlier attempt at auto-relating `gold_compliance_exceptions` to `gold_fact_sales` on `customer_id` created a many-to-many relationship, which Power BI resolves silently and can produce incorrect numbers in visuals without any error message.

## DimDate — fiscal year calculated table
India's fiscal year runs April to March, matching `Monthly_Targets`' own Apr-24 through Mar-25 columns.

```dax
DimDate =
VAR MinDate = MIN(gold_fact_sales[txn_date])
VAR MaxDate = MAX(gold_fact_sales[txn_date])
RETURN
ADDCOLUMNS(
    CALENDAR(MinDate, MaxDate),
    "MonthName", FORMAT([Date], "MMM"),
    "MonthYear", FORMAT([Date], "MMM-YY"),
    "FiscalYear", "FY" & FORMAT(IF(MONTH([Date])>=4, YEAR([Date])+1, YEAR([Date])), "00"),
    "FiscalQuarter", "FQ" & ROUNDUP((IF(MONTH([Date])>=4, MONTH([Date])-3, MONTH([Date])+9))/3, 0),
    "FiscalMonthNum", IF(MONTH([Date])>=4, MONTH([Date])-3, MONTH([Date])+9)
)
```
`MonthName` is sorted by `FiscalMonthNum` (Column tools → Sort by column) so charts read Apr→Mar instead of alphabetically.

## Field parameter — Breakdown By
One flexible chart replaces four separate ones. Modeling → New parameter → Fields, built from `gold_fact_sales[region]`, `[branch]`, `[product_category]`, `[sales_rep]`, `[risk_rating]`. Drives a single clustered bar chart (Axis = parameter, Value = Total Net Sales) with a tile-style slicer letting the viewer switch dimensions.

## Measures

```dax
Total Net Sales = SUM(gold_fact_sales[net_amount])

Total Transactions = COUNTROWS(gold_fact_sales)

Total Target = SUM(gold_sales_vs_target[target_amount])

Total Actual = SUM(gold_sales_vs_target[actual_amount])

Target Achievement % = DIVIDE([Total Actual], [Total Target])

Sales Exceptions = CALCULATE(
    COUNTROWS(gold_compliance_exceptions),
    gold_compliance_exceptions[source_type] = "Sales Transaction"
)

% Sales With Exception = DIVIDE([Sales Exceptions], [Total Transactions])

Total Compliance Exceptions = COUNTROWS(gold_compliance_exceptions)
```

**Note on `Target Achievement %`**: this measure is present in the model but not shown on the dashboard. `Monthly_Targets` and `Sales_Transactions` were built on incompatible scales (see main README) — Actual/Target comes out to ~1898%, which is not a meaningful ratio. Kept in the model as a documented finding, not hidden, but deliberately excluded from the KPI row so the dashboard doesn't present a number that looks broken.

## Dashboard layout
- 4 KPI cards: Total Net Sales, Total Transactions, % Sales With Exception, Total Target
- 2 slicers: Period (DimDate fiscal hierarchy), Status
- 1 field-parameter bar chart (5 breakdown dimensions)
- 1 trend line: Total Net Sales by fiscal month
- 1 matrix: compliance exceptions by source type and reason (128 GST / 57 PAN / 38 both for Sales; 8 GST / 3 PAN / 3 both for Customer)
