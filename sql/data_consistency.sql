-- AML Behavioural Risk Feature Engineering & Detection Intelligence System
-- Check whether the imported data is consistent enough for feature engineering.
-- MySQL 8.0+ | Database: aml_behavioural_risk_fe
-- Read-only: nothing here updates or deletes records.

USE aml_behavioural_risk_fe;

-- Query 1: Check whether customer expectations are usable for comparisons.
SELECT
    COUNT(*) AS total_customers,
    SUM(expected_monthly_turnover_usd <= 0 OR expected_monthly_turnover_usd IS NULL)
        AS unusable_expected_turnover,
    SUM(expected_monthly_txn_count <= 0 OR expected_monthly_txn_count IS NULL)
        AS unusable_expected_txn_count,
    SUM(profile_as_of <> '2026-01-01' OR profile_as_of IS NULL)
        AS unexpected_profile_dates
FROM customers;

-- Later, we'll compare actual activity with each customer's expected activity.
-- A zero or missing expectation would make a ratio unreliable, so we check it now.
-- This doesn't tell us whether the expectation itself is realistic or up to date.


-- Query 2: Look at the payment channel, direction and transaction type together.
SELECT
    channel,
    direction,
    transaction_type,
    COUNT(*) AS transaction_count,
    CASE
        WHEN (channel = 'ACH' AND direction = 'IN' AND transaction_type = 'ACH_CREDIT')
          OR (channel = 'ACH' AND direction = 'OUT' AND transaction_type = 'ACH_DEBIT')
          OR (channel = 'CARD' AND direction = 'IN' AND transaction_type = 'CARD_RECEIPT')
          OR (channel = 'CARD' AND direction = 'OUT' AND transaction_type = 'CARD_PAYMENT')
          OR (channel = 'CASH' AND direction = 'IN' AND transaction_type = 'CASH_DEPOSIT')
          OR (channel = 'CASH' AND direction = 'OUT' AND transaction_type = 'CASH_WITHDRAWAL')
          OR (channel = 'WIRE' AND direction = 'IN' AND transaction_type = 'WIRE_IN')
          OR (channel = 'WIRE' AND direction = 'OUT' AND transaction_type = 'WIRE_OUT')
        THEN 'EXPECTED'
        ELSE 'REVIEW'
    END AS mapping_check
FROM transactions
GROUP BY channel, direction, transaction_type
ORDER BY channel, direction, transaction_type;

-- A debit should not accidentally be labelled as money coming in.
-- We'll use direction when calculating inflows, outflows and pass-through activity.
-- If a combination shows REVIEW, we should inspect it before building those features.


-- Query 3: Check how long transactions take to post after they occur.
SELECT
    CASE
        WHEN posted_at = occurred_at THEN 'Same timestamp'
        WHEN posted_at < DATE_ADD(occurred_at, INTERVAL 24 HOUR) THEN 'Under 24 hours'
        WHEN posted_at < DATE_ADD(occurred_at, INTERVAL 48 HOUR) THEN '24 to under 48 hours'
        ELSE '48 hours or more'
    END AS posting_delay_group,
    COUNT(*) AS transaction_count,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, occurred_at, posted_at) / 60.0), 2)
        AS average_delay_hours
FROM transactions
GROUP BY posting_delay_group
ORDER BY FIELD(posting_delay_group,
    'Same timestamp', 'Under 24 hours',
    '24 to under 48 hours', '48 hours or more');

-- Occurrence time and posting time are not the same thing.
-- For suspicious-behaviour features, we'll normally use occurred_at so a posting
-- delay doesn't make transactions look as if they happened on the wrong day.
-- A long delay is something to understand, not automatically a data error.


-- Query 4: Identify transactions that do not have a full 30 days of history
-- inside our dataset. This matters when we start creating rolling features.
SELECT
    COUNT(*) AS total_transactions,
    SUM(occurred_at < '2026-01-31 00:00:00')
        AS transactions_without_full_dataset_30d_history,
    SUM(occurred_at >= '2026-01-31 00:00:00')
        AS transactions_with_30d_dataset_history,
    COUNT(DISTINCT CASE
        WHEN occurred_at < '2026-01-31 00:00:00' THEN account_id
    END) AS affected_accounts
FROM transactions;

-- Our dataset starts on January 1, 2026. For transactions in the first 30
-- days, we cannot see the full preceding 30 days even for older accounts.
-- We must not treat this missing history as zero activity. We'll flag those
-- early observations or handle them separately during feature engineering.


-- Query 5: Recheck amount boundaries before choosing any risk thresholds.
SELECT
    COUNT(*) AS total_transactions,
    SUM(amount_usd <= 0 OR amount_usd IS NULL) AS invalid_amounts,
    MIN(amount_usd) AS minimum_amount_usd,
    MAX(amount_usd) AS maximum_amount_usd,
    SUM(amount_usd = 75000) AS exactly_75000,
    SUM(amount_usd > 75000) AS above_75000
FROM transactions;

-- We saw the same $75,000 maximum in every channel. That might reflect a
-- limit in the synthetic data rather than real customer behaviour.
-- We'll keep these transactions but document the possible ceiling, so we
-- don't overstate what our high-value detection rules can prove.
