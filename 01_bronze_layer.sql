-- =====================================================================
-- BRONZE LAYER
-- Raw landing tables. Every column is TEXT on purpose — nothing is
-- cleaned here. This is the untouched copy of the source data, same
-- idea as an audit workpaper: nothing altered from what was received.
-- =====================================================================

USE banking_etl_project;

DROP TABLE IF EXISTS bronze_sales_transactions;
CREATE TABLE bronze_sales_transactions (
    Transaction_ID   TEXT,
    Date             TEXT,
    Customer_Name    TEXT,
    Customer_ID      TEXT,
    Region           TEXT,
    Branch           TEXT,
    Product_Category TEXT,
    Product_Name     TEXT,
    Qty              TEXT,
    Unit_Price       TEXT,
    Total_Amount     TEXT,
    `Discount_%`     TEXT,
    Net_Amount       TEXT,
    Payment_Mode     TEXT,
    Sales_Rep        TEXT,
    Status           TEXT,
    Invoice_No       TEXT,
    GST_No           TEXT,
    PAN              TEXT,
    Remarks          TEXT
);

DROP TABLE IF EXISTS bronze_customer_master;
CREATE TABLE bronze_customer_master (
    Customer_ID      TEXT,
    Customer_Name    TEXT,
    Contact_Person   TEXT,
    Phone            TEXT,
    Email            TEXT,
    Address          TEXT,
    City             TEXT,
    State            TEXT,
    PIN_Code         TEXT,
    GST_No           TEXT,
    PAN              TEXT,
    Credit_Limit     TEXT,
    Outstanding      TEXT,
    Risk_Rating      TEXT,
    Onboarding_Date  TEXT,
    KYC_Status       TEXT
);

DROP TABLE IF EXISTS bronze_monthly_targets;
CREATE TABLE bronze_monthly_targets (
    Sales_Rep       TEXT,
    Region          TEXT,
    `Apr-24`        TEXT,
    `May-24`        TEXT,
    `Jun-24`        TEXT,
    `Jul-24`        TEXT,
    `Aug-24`        TEXT,
    `Sep-24`        TEXT,
    `Oct-24`        TEXT,
    `Nov-24`        TEXT,
    `Dec-24`        TEXT,
    `Jan-25`        TEXT,
    `Feb-25`        TEXT,
    `Mar-25`        TEXT,
    Annual_Target   TEXT
);

DROP TABLE IF EXISTS bronze_product_pricing;
CREATE TABLE bronze_product_pricing (
    Product_Category TEXT,
    Product_Name     TEXT,
    Base_Price       TEXT,
    `GST_Rate_%`     TEXT,
    `Commission_%`   TEXT,
    Min_Qty          TEXT,
    `Max_Discount_%` TEXT
);

-- After creating these, import the four CSVs (exported from the source
-- Excel workbook) into their matching table via the Table Data Import
-- Wizard in MySQL Workbench.
