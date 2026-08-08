-- =====================================================================
-- GOLD LAYER — Fact Sales
-- Every valid sale, enriched with customer details.
--
-- The AND c.record_status = 'VALID' on the join is not optional. Without
-- it, this join hits a real bug: silver_customer_clean still holds the
-- duplicate CUST-1001 row we flagged as a reject, so any sale for that
-- customer would match TWO customer rows and get silently duplicated —
-- a "join fan-out". Caught this because the row count came back 401
-- instead of the expected 387.
-- =====================================================================

USE banking_etl_project;

DROP TABLE IF EXISTS gold_fact_sales;

CREATE TABLE gold_fact_sales AS
SELECT
    s.transaction_id,
    s.txn_date,
    s.customer_id,
    c.customer_name,
    c.city,
    c.state,
    c.risk_rating,
    s.region_clean AS region,
    s.branch_clean AS branch,
    s.product_category_clean AS product_category,
    s.product_name,
    s.qty_clean AS qty,
    s.unit_price_clean AS unit_price,
    s.total_amount_clean AS total_amount,
    s.discount_pct_clean AS discount_pct,
    s.net_amount_clean AS net_amount,
    s.payment_mode_clean AS payment_mode,
    s.sales_rep,
    s.status_clean AS status
FROM silver_sales_clean s
LEFT JOIN silver_customer_clean c
    ON s.customer_id = c.customer_id
    AND c.record_status = 'VALID'   -- only match the one clean copy of each customer
WHERE s.record_status = 'VALID';

-- Result: 387 rows. Customer fields are NULL for transactions referencing
-- customer IDs that exist in Sales_Transactions but were never captured
-- in Customer_Master — a real data-completeness gap, not a join bug.
