-- =====================================================================
-- SILVER LAYER — Monthly Targets & Product Pricing
-- Both sheets were already clean in the source data — no typos, no
-- format chaos. Deliberately kept simple here: type-casting only, no
-- reject/valid logic. Matching heavy validation to already-clean
-- reference data would be validation theater, not real controls —
-- risk-based effort, not a one-size-fits-all script.
-- =====================================================================

USE banking_etl_project;

DROP TABLE IF EXISTS silver_monthly_targets_clean;
CREATE TABLE silver_monthly_targets_clean AS
SELECT
    TRIM(Sales_Rep) AS sales_rep,
    TRIM(Region) AS region,
    CAST(`Apr-24` AS DECIMAL(18,2)) AS apr_24,
    CAST(`May-24` AS DECIMAL(18,2)) AS may_24,
    CAST(`Jun-24` AS DECIMAL(18,2)) AS jun_24,
    CAST(`Jul-24` AS DECIMAL(18,2)) AS jul_24,
    CAST(`Aug-24` AS DECIMAL(18,2)) AS aug_24,
    CAST(`Sep-24` AS DECIMAL(18,2)) AS sep_24,
    CAST(`Oct-24` AS DECIMAL(18,2)) AS oct_24,
    CAST(`Nov-24` AS DECIMAL(18,2)) AS nov_24,
    CAST(`Dec-24` AS DECIMAL(18,2)) AS dec_24,
    CAST(`Jan-25` AS DECIMAL(18,2)) AS jan_25,
    CAST(`Feb-25` AS DECIMAL(18,2)) AS feb_25,
    CAST(`Mar-25` AS DECIMAL(18,2)) AS mar_25,
    CAST(Annual_Target AS DECIMAL(18,2)) AS annual_target
FROM bronze_monthly_targets;

DROP TABLE IF EXISTS silver_product_pricing_clean;
CREATE TABLE silver_product_pricing_clean AS
SELECT
    TRIM(Product_Category) AS product_category,
    TRIM(Product_Name) AS product_name,
    CAST(Base_Price AS DECIMAL(18,2)) AS base_price,
    CAST(`GST_Rate_%` AS DECIMAL(5,2)) AS gst_rate_pct,
    CAST(`Commission_%` AS DECIMAL(5,2)) AS commission_pct,
    CAST(Min_Qty AS UNSIGNED) AS min_qty,
    CAST(`Max_Discount_%` AS DECIMAL(5,2)) AS max_discount_pct
FROM bronze_product_pricing;

-- Result: 10 rows (targets), 25 rows (pricing) — no rejects
