-- AML Behavioural Risk Feature Engineering
-- Data profiling: checking missing information before we build risk features
-- Database: aml_behavioural_risk_fe (MySQL 8.0+)
-- These queries only read the data; they do not change any records.

USE aml_behavioural_risk_fe;

-- Query 1: See which transaction details are missing in each payment channel.
-- Breaking this down by channel helps us spot problems that an overall total could hide.
SELECT
    channel,
    COUNT(*) AS total_transactions,
    SUM(counterparty_id IS NULL) AS missing_counterparty_id,
    SUM(account_id IS NULL OR TRIM(account_id) = '') AS missing_account_id,
    SUM(amount_usd IS NULL) AS missing_amount,
    SUM(occurred_at IS NULL) AS missing_occurred_at,
    SUM(posted_at IS NULL) AS missing_posted_at,
    SUM(direction IS NULL OR TRIM(direction) = '') AS missing_direction,
    SUM(purpose_code IS NULL OR TRIM(purpose_code) = '') AS missing_purpose_code,
    SUM(reference_code IS NULL OR TRIM(reference_code) = '') AS missing_reference_code
FROM transactions
GROUP BY channel
ORDER BY channel;

-- What I'm checking:
-- Cash payments in this dataset do not have a counterparty ID, so that gap is expected.
-- For ACH, CARD and WIRE payments, a missing counterparty ID would need a closer look.
-- Missing account IDs, amounts or dates would be more serious: we need those fields
-- to build reliable transaction histories and compare a customer's activity over time.
-- I would investigate unexpected gaps, not fill them with made-up values.


-- Query 2: Check whether customer, account and counterparty records have the
-- details we'll need when we start comparing actual activity with customer profiles.
SELECT
    'customers' AS table_name,
    COUNT(*) AS total_rows,
    SUM(
        customer_type IS NULL OR TRIM(customer_type) = '' OR
        customer_name IS NULL OR TRIM(customer_name) = '' OR
        home_country IS NULL OR TRIM(home_country) = '' OR
        baseline_risk_rating IS NULL OR TRIM(baseline_risk_rating) = '' OR
        onboarded_at IS NULL OR
        expected_monthly_turnover_usd IS NULL OR
        expected_monthly_txn_count IS NULL OR
        pep_flag IS NULL
    ) AS rows_missing_key_attributes
FROM customers

UNION ALL

SELECT
    'accounts',
    COUNT(*),
    SUM(
        customer_id IS NULL OR TRIM(customer_id) = '' OR
        account_type IS NULL OR TRIM(account_type) = '' OR
        opened_at IS NULL OR
        account_currency IS NULL OR TRIM(account_currency) = '' OR
        account_status_as_of_start IS NULL OR TRIM(account_status_as_of_start) = ''
    )
FROM accounts

UNION ALL

SELECT
    'counterparties',
    COUNT(*),
    SUM(
        counterparty_name IS NULL OR TRIM(counterparty_name) = '' OR
        counterparty_type IS NULL OR TRIM(counterparty_type) = '' OR
        registration_country IS NULL OR TRIM(registration_country) = ''
    )
FROM counterparties;

-- What I'm checking:
-- Customer risk ratings and expected activity will help us judge whether a
-- transaction pattern is unusual for that specific customer. Account opening
-- dates and counterparty details also give us important context.
-- This query counts a row once if any of its checked fields is missing;
-- it does not tell us how many individual cells are blank.
-- A result of zero is good, but we still need separate checks for incorrect
-- values and dates. A filled-in field is not necessarily a correct field.


-- Query 3: Double-check that missing counterparty IDs follow the cash-payment rule.
SELECT
    SUM(channel = 'CASH' AND counterparty_id IS NULL)
        AS valid_cash_missing_counterparty,
    SUM(channel = 'CASH' AND counterparty_id IS NOT NULL)
        AS cash_unexpected_counterparty,
    SUM(channel <> 'CASH' AND counterparty_id IS NULL)
        AS noncash_missing_counterparty
FROM transactions;

-- What I'm checking:
-- In this training dataset, cash transactions are recorded without a
-- counterparty ID. We should keep those NULLs because they reflect how
-- these records were designed, not a mistake to 'clean' away.
-- If the other two counts are above zero, I would inspect those records
-- before using counterparty information in our risk features.
