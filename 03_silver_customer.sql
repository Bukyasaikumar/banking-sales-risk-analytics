-- =====================================================================
-- SILVER LAYER — Customer Master
-- Onboarding_Date alone has 6 distinct real formats in this dataset:
-- ISO dash, ISO slash, DD-Mon-YYYY, "DD Mon YYYY", "Month DD, YYYY",
-- and ambiguous DD/MM vs MM/DD slash dates (resolved by whichever
-- number in the pair can't possibly be a month).
-- =====================================================================

USE banking_etl_project;

DROP TABLE IF EXISTS silver_customer_clean;

CREATE TABLE silver_customer_clean AS
WITH cleaned AS (
    SELECT
        NULLIF(TRIM(Customer_ID), '') AS customer_id,
        NULLIF(TRIM(Customer_Name), '') AS customer_name,
        NULLIF(TRIM(Contact_Person), '') AS contact_person,
        NULLIF(REGEXP_REPLACE(Phone, '[^0-9]', ''), '') AS phone_clean,
        NULLIF(TRIM(Email), '') AS email_clean,
        NULLIF(TRIM(Address), '') AS address,
        NULLIF(TRIM(City), '') AS city,
        NULLIF(TRIM(State), '') AS state,
        NULLIF(REGEXP_REPLACE(PIN_Code, '[^0-9]', ''), '') AS pin_code_clean,
        NULLIF(TRIM(GST_No), '') AS gst_no_raw,
        NULLIF(TRIM(PAN), '') AS pan_raw,
        CAST(NULLIF(REGEXP_REPLACE(Credit_Limit, '[^0-9.]', ''), '') AS DECIMAL(18,2)) AS credit_limit,
        CAST(NULLIF(REGEXP_REPLACE(Outstanding, '[^0-9.]', ''), '') AS DECIMAL(18,2)) AS outstanding,
        UPPER(NULLIF(TRIM(Risk_Rating), '')) AS risk_rating,

        CASE
            WHEN TRIM(Onboarding_Date) = '' THEN NULL
            WHEN Onboarding_Date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(Onboarding_Date, '%Y-%m-%d')
            WHEN Onboarding_Date REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$' THEN STR_TO_DATE(Onboarding_Date, '%Y/%m/%d')
            WHEN Onboarding_Date REGEXP '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(Onboarding_Date, '%d-%b-%Y')
            WHEN Onboarding_Date REGEXP '^[0-9]{1,2} [A-Za-z]{3} [0-9]{4}$' THEN STR_TO_DATE(Onboarding_Date, '%d %b %Y')
            WHEN Onboarding_Date REGEXP '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$' THEN STR_TO_DATE(Onboarding_Date, '%M %d, %Y')
            -- ambiguous slash dates: whichever number can't be a month wins
            WHEN Onboarding_Date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
                 AND CAST(SUBSTRING_INDEX(Onboarding_Date, '/', 1) AS UNSIGNED) > 12
                THEN STR_TO_DATE(Onboarding_Date, '%d/%m/%Y')
            WHEN Onboarding_Date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
                 AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(Onboarding_Date,'/',2),'/',-1) AS UNSIGNED) > 12
                THEN STR_TO_DATE(Onboarding_Date, '%m/%d/%Y')
            WHEN Onboarding_Date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
                THEN STR_TO_DATE(Onboarding_Date, '%d/%m/%Y')  -- truly ambiguous: Indian convention default
            ELSE NULL
        END AS onboarding_date_clean,

        CASE UPPER(TRIM(KYC_Status))
            WHEN 'COMPLETED' THEN 'Completed'
            WHEN 'DONE'      THEN 'Completed'
            WHEN 'PENDING'   THEN 'Pending'
            WHEN 'EXPIRED'   THEN 'Expired'
            ELSE NULL
        END AS kyc_status_clean
    FROM bronze_customer_master
),
flagged AS (
    SELECT
        c.*,
        CASE WHEN pan_raw REGEXP '^[A-Z]{5}[0-9]{4}[A-Z]{1}$' THEN 1 ELSE 0 END AS is_valid_pan,
        CASE WHEN gst_no_raw REGEXP '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9A-Z]{1}Z[0-9A-Z]{1}$' THEN 1 ELSE 0 END AS is_valid_gst,
        CASE WHEN phone_clean IS NOT NULL AND LENGTH(phone_clean) = 10 THEN 1 ELSE 0 END AS is_valid_phone,
        CASE WHEN pin_code_clean IS NOT NULL AND LENGTH(pin_code_clean) = 6 THEN 1 ELSE 0 END AS is_valid_pin,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS dup_rank
    FROM cleaned c
)
SELECT
    *,
    CASE WHEN dup_rank > 1 THEN 1 ELSE 0 END AS is_duplicate_customer,
    CASE
        WHEN customer_id IS NULL
          OR customer_name IS NULL
          OR dup_rank > 1
        THEN 'REJECT'
        ELSE 'VALID'
    END AS record_status
FROM flagged;

DROP TABLE IF EXISTS silver_customer_rejects;
CREATE TABLE silver_customer_rejects AS
SELECT * FROM silver_customer_clean WHERE record_status = 'REJECT';

-- Result: 21 total, 19 valid, 2 reject (1 duplicate customer, 1 near-blank record)
