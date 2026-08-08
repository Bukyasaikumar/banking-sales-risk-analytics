-- =====================================================================
-- SILVER LAYER — Sales Transactions
-- Cleans and standardizes the raw data, flags PAN/GST format validity
-- as separate compliance flags (not rejection reasons), and separates
-- business validity (record_status) from documentation completeness.
-- Any row that fails is kept in silver_sales_rejects with the reason
-- implicit in which condition it failed — nothing is silently dropped.
-- =====================================================================

USE banking_etl_project;

DROP TABLE IF EXISTS silver_sales_clean;

CREATE TABLE silver_sales_clean AS
WITH cleaned AS (
    SELECT
        NULLIF(TRIM(Transaction_ID), '') AS transaction_id,

        -- Date mixes plain Excel serial numbers with formatted date text
        -- (Excel's CSV export writes date-formatted cells as readable
        -- text, e.g. '21-Aug-2024', while unformatted cells stay numeric)
        CASE
            WHEN TRIM(Date) = '' THEN NULL
            WHEN Date REGEXP '^[0-9]+$' THEN DATE_ADD('1899-12-30', INTERVAL CAST(Date AS UNSIGNED) DAY)
            WHEN Date REGEXP '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(Date, '%d-%b-%Y')
            ELSE NULL
        END AS txn_date,

        NULLIF(TRIM(Customer_ID), '') AS customer_id,
        NULLIF(TRIM(Customer_Name), '') AS customer_name,

        -- Region: single-letter codes + mixed case, collapsed to one value
        CASE UPPER(TRIM(Region))
            WHEN 'N' THEN 'North'  WHEN 'NORTH' THEN 'North'
            WHEN 'S' THEN 'South'  WHEN 'SOUTH' THEN 'South'
            WHEN 'E' THEN 'East'   WHEN 'EAST'  THEN 'East'
            WHEN 'W' THEN 'West'   WHEN 'WEST'  THEN 'West'
            WHEN 'CENTRAL' THEN 'Central'
            ELSE NULL
        END AS region_clean,

        -- Branch: known typos fixed first, then case standardized
        CASE
            WHEN UPPER(TRIM(Branch)) = 'AHEMDABAD' THEN 'Ahmedabad'
            WHEN UPPER(TRIM(Branch)) = 'BANGALROE' THEN 'Bangalore'
            WHEN UPPER(TRIM(Branch)) = 'HYDERBAD'  THEN 'Hyderabad'
            WHEN UPPER(TRIM(Branch)) = 'JAIPPUR'   THEN 'Jaipur'
            WHEN UPPER(TRIM(Branch)) = 'NAGPPUR'   THEN 'Nagpur'
            WHEN UPPER(TRIM(Branch)) = 'PATANA'    THEN 'Patna'
            ELSE CONCAT(UPPER(LEFT(TRIM(Branch),1)), LOWER(SUBSTRING(TRIM(Branch),2)))
        END AS branch_clean,

        -- Product category: fixes the 'Lonas' typo, standardizes case
        CASE
            WHEN UPPER(TRIM(Product_Category)) IN ('LONAS','LOANS') THEN 'Loans'
            WHEN UPPER(TRIM(Product_Category)) = 'MUTUAL FUNDS'     THEN 'Mutual Funds'
            WHEN UPPER(TRIM(Product_Category)) = 'FIXED DEPOSITS'   THEN 'Fixed Deposits'
            WHEN UPPER(TRIM(Product_Category)) = 'CREDIT CARDS'     THEN 'Credit Cards'
            WHEN UPPER(TRIM(Product_Category)) = 'INSURANCE'        THEN 'Insurance'
            ELSE NULL
        END AS product_category_clean,

        NULLIF(TRIM(Product_Name), '') AS product_name,

        CAST(NULLIF(REGEXP_REPLACE(Qty, '[^0-9]', ''), '') AS UNSIGNED) AS qty_clean,
        CAST(NULLIF(REGEXP_REPLACE(Unit_Price, '[^0-9.]', ''), '')   AS DECIMAL(18,2)) AS unit_price_clean,
        CAST(NULLIF(REGEXP_REPLACE(Total_Amount, '[^0-9.]', ''), '') AS DECIMAL(18,2)) AS total_amount_clean,
        CAST(NULLIF(REGEXP_REPLACE(`Discount_%`, '[^0-9.]', ''), '') AS DECIMAL(5,2))  AS discount_pct_clean,
        CAST(NULLIF(REGEXP_REPLACE(Net_Amount, '[^0-9.]', ''), '')   AS DECIMAL(18,2)) AS net_amount_clean,

        UPPER(NULLIF(TRIM(Payment_Mode), '')) AS payment_mode_clean,
        NULLIF(TRIM(Sales_Rep), '') AS sales_rep,

        CASE UPPER(TRIM(Status))
            WHEN 'COMPLETED'  THEN 'Completed'
            WHEN 'PENDING'    THEN 'Pending'
            WHEN 'CANCELLED'  THEN 'Cancelled'
            WHEN 'FAILED'     THEN 'Failed'
            WHEN 'IN PROCESS' THEN 'In Process'
            WHEN 'REFUNDED'   THEN 'Refunded'
            ELSE NULL
        END AS status_clean,

        NULLIF(TRIM(Invoice_No), '') AS invoice_no,
        NULLIF(TRIM(GST_No), '') AS gst_no_raw,
        NULLIF(TRIM(PAN), '') AS pan_raw
    FROM bronze_sales_transactions
),
flagged AS (
    SELECT
        c.*,
        -- Compliance flags — kept separate from business validity below
        CASE WHEN pan_raw REGEXP '^[A-Z]{5}[0-9]{4}[A-Z]{1}$' THEN 1 ELSE 0 END AS is_valid_pan,
        CASE WHEN gst_no_raw REGEXP '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9A-Z]{1}Z[0-9A-Z]{1}$' THEN 1 ELSE 0 END AS is_valid_gst,
        ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY transaction_id) AS dup_rank
    FROM cleaned c
)
SELECT
    *,
    CASE WHEN dup_rank > 1 THEN 1 ELSE 0 END AS is_duplicate_txn,
    -- Business validity: can we trust this as a real, unique transaction?
    -- PAN/GST format issues do NOT reject a sale on their own — that's
    -- a documentation-completeness question, handled separately.
    CASE
        WHEN transaction_id IS NULL
          OR customer_id IS NULL
          OR invoice_no IS NULL
          OR dup_rank > 1
        THEN 'REJECT'
        ELSE 'VALID'
    END AS record_status
FROM flagged;

DROP TABLE IF EXISTS silver_sales_rejects;
CREATE TABLE silver_sales_rejects AS
SELECT * FROM silver_sales_clean WHERE record_status = 'REJECT';

-- Result: 505 total, 387 valid, 118 reject
