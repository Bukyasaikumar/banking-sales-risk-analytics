-- =====================================================================
-- GOLD LAYER — Sales vs. Target
-- Three steps: actuals aggregated by rep/month, targets unpivoted from
-- wide to long, then joined together.
--
-- Sales_Rep names were never standardized in Silver (only Region,
-- Branch, Product_Category, and Status were) — the same person shows
-- up as "Rahul Sharma" / "RAHUL SHARMA" / "rahul sharma" / "R. Sharma".
-- Fixed here at the Gold layer via surname matching, since matching to
-- the 10 named reps in Monthly_Targets is a reporting-layer decision,
-- not a general cleaning rule.
--
-- KNOWN LIMITATION: Monthly_Targets and Sales_Transactions were built on
-- incompatible scales — average target ~Rs 4.6L per rep/month vs. average
-- transaction value ~Rs 28.7L. Actual-vs-target comparisons in this table
-- (and any % achievement derived from them) are not meaningful as a ratio.
-- Shown as reported, not adjusted — see README.
-- =====================================================================

USE banking_etl_project;

DROP TABLE IF EXISTS gold_sales_actuals_by_month;
CREATE TABLE gold_sales_actuals_by_month AS
SELECT
    CASE
        WHEN sales_rep REGEXP 'Sharma$' THEN 'Rahul Sharma'
        WHEN sales_rep REGEXP 'Patel$'  THEN 'Priya Patel'
        WHEN sales_rep REGEXP 'Kumar$'  THEN 'Amit Kumar'
        WHEN sales_rep REGEXP 'Gupta$'  THEN 'Sneha Gupta'
        WHEN sales_rep REGEXP 'Singh$'  THEN 'Vikram Singh'
        WHEN sales_rep REGEXP 'Reddy$'  THEN 'Neha Reddy'
        WHEN sales_rep REGEXP 'Iyer$'   THEN 'Rajesh Iyer'
        WHEN sales_rep REGEXP 'Joshi$'  THEN 'Meena Joshi'
        WHEN sales_rep REGEXP 'Verma$'  THEN 'Deepak Verma'
        WHEN sales_rep REGEXP 'Desai$'  THEN 'Anita Desai'
        ELSE sales_rep
    END AS sales_rep_clean,
    DATE_FORMAT(txn_date, '%b-%y') AS period,
    SUM(net_amount) AS actual_amount
FROM gold_fact_sales
WHERE txn_date IS NOT NULL
GROUP BY sales_rep_clean, period;

DROP TABLE IF EXISTS gold_monthly_targets_long;
CREATE TABLE gold_monthly_targets_long AS
SELECT sales_rep, 'Apr-24' AS period, apr_24 AS target_amount FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'May-24', may_24 FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'Jun-24', jun_24 FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'Jul-24', jul_24 FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'Aug-24', aug_24 FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'Sep-24', sep_24 FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'Oct-24', oct_24 FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'Nov-24', nov_24 FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'Dec-24', dec_24 FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'Jan-25', jan_25 FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'Feb-25', feb_25 FROM silver_monthly_targets_clean
UNION ALL SELECT sales_rep, 'Mar-25', mar_25 FROM silver_monthly_targets_clean;

DROP TABLE IF EXISTS gold_sales_vs_target;
CREATE TABLE gold_sales_vs_target AS
SELECT
    t.sales_rep,
    t.period,
    t.target_amount,
    COALESCE(a.actual_amount, 0) AS actual_amount,
    COALESCE(a.actual_amount, 0) - t.target_amount AS variance_amount,
    ROUND((COALESCE(a.actual_amount, 0) - t.target_amount) / t.target_amount * 100, 1) AS variance_pct
FROM gold_monthly_targets_long t
LEFT JOIN gold_sales_actuals_by_month a
    ON t.sales_rep = a.sales_rep_clean
    AND t.period = a.period;

-- Result: 120 rows (10 reps x 12 months)
