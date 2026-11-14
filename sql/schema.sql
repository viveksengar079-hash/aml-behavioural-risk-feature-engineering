-- I used these tables to store the original customer and transaction data.
-- Run this once in a fresh database, then import the CSV files.

CREATE DATABASE IF NOT EXISTS aml_behavioural_risk_fe;
USE aml_behavioural_risk_fe;

-- Customer details, including the activity we normally expect from them.
CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(12) PRIMARY KEY,
    customer_type VARCHAR(20),
    customer_name VARCHAR(100),
    home_country VARCHAR(5),
    customer_segment VARCHAR(30),
    industry_or_occupation VARCHAR(60),
    onboarded_at DATE,
    baseline_risk_rating VARCHAR(20),
    expected_monthly_turnover_usd DECIMAL(18,2),
    expected_monthly_txn_count INT,
    pep_flag TINYINT,
    profile_as_of DATE
);

-- Each account belongs to a customer.
CREATE TABLE IF NOT EXISTS accounts (
    account_id VARCHAR(12) PRIMARY KEY,
    customer_id VARCHAR(12),
    account_type VARCHAR(30),
    opened_at DATE,
    account_currency VARCHAR(5),
    account_status_as_of_start VARCHAR(20),
    branch_region VARCHAR(30)
);

-- Basic details of people and businesses involved in transactions.
CREATE TABLE IF NOT EXISTS counterparties (
    counterparty_id VARCHAR(12) PRIMARY KEY,
    counterparty_name VARCHAR(100),
    counterparty_type VARCHAR(30),
    registration_country VARCHAR(5),
    sector VARCHAR(60)
);

-- Transaction records used to study account activity.
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id VARCHAR(16) PRIMARY KEY,
    account_id VARCHAR(12),
    counterparty_id VARCHAR(12) NULL,
    occurred_at DATETIME,
    posted_at DATETIME,
    direction VARCHAR(5),
    channel VARCHAR(15),
    transaction_type VARCHAR(40),
    amount_usd DECIMAL(18,2),
    currency VARCHAR(5),
    purpose_code VARCHAR(40),
    reference_code VARCHAR(20)
);

-- Quick count check after importing all four CSVs.
SELECT 'customers' AS table_name, COUNT(*) AS records FROM customers
UNION ALL
SELECT 'accounts', COUNT(*) FROM accounts
UNION ALL
SELECT 'counterparties', COUNT(*) FROM counterparties
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions;
