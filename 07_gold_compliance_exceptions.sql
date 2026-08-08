-- =====================================================================
-- GOLD LAYER — Compliance Exceptions
-- Every Sales or Customer record that failed a PAN or GST format check,
-- pulled into one exception list. This is the controls/audit output of
-- the pipeline: not a pass/fail on the whole record, a clean list of
-- what's wrong and where — the same shape as a real audit exception
-- report. Deliberately left unrelated to gold_fact_sales in the Power BI
-- model (a shared customer dimension would be needed for a clean
-- relationship; the alternative was a many-to-many join, which silently
-- produces wrong numbers).
-- =====================================================================

USE banking_etl_project;

DROP TABLE IF EXISTS gold_compliance_exceptions;

CREATE TABLE gold_compliance_exceptions AS
SELECT
    'Sales Transaction' AS source_type,
    transaction_id AS record_id,
    customer_id,
    pan_raw,
    gst_no_raw,
    CASE
        WHEN is_valid_pan = 0 AND is_valid_gst = 0 THEN 'Invalid PAN and GST'
        WHEN is_valid_pan = 0 THEN 'Invalid PAN'
        WHEN is_valid_gst = 0 THEN 'Invalid GST'
    END AS exception_reason
FROM silver_sales_clean
WHERE is_valid_pan = 0 OR is_valid_gst = 0

UNION ALL

SELECT
    'Customer Record' AS source_type,
    customer_id AS record_id,
    customer_id,
    pan_raw,
    gst_no_raw,
    CASE
        WHEN is_valid_pan = 0 AND is_valid_gst = 0 THEN 'Invalid PAN and GST'
        WHEN is_valid_pan = 0 THEN 'Invalid PAN'
        WHEN is_valid_gst = 0 THEN 'Invalid GST'
    END AS exception_reason
FROM silver_customer_clean
WHERE is_valid_pan = 0 OR is_valid_gst = 0;

-- Result: 237 total exceptions
--   Sales Transaction: 128 GST, 57 PAN, 38 both  (223 total — ~44% of all 505 sales rows)
--   Customer Record:     8 GST,  3 PAN,  3 both  ( 14 total)
