-- AML Behavioural Risk Feature Engineering & Detection Intelligence System
-- Feature readiness checks before we start the main analysis.
-- Run in MySQL Workbench (MySQL 8.0+). These queries only read the data.

USE aml_behavioural_risk_fe;

-- 1. Check which customer groups we can compare fairly.
-- We're looking at customer type, existing risk rating and expected activity.
SELECT
    customer_type,
    baseline_risk_rating,
    COUNT(*) AS total_customers,
    SUM(pep_flag = 1) AS pep_customers,
    ROUND(AVG(expected_monthly_txn_count), 2) AS avg_expected_monthly_txn_count,
    ROUND(AVG(expected_monthly_turnover_usd), 2) AS avg_expected_monthly_turnover_usd
FROM customers
GROUP BY customer_type, baseline_risk_rating
ORDER BY customer_type, FIELD(baseline_risk_rating, 'LOW', 'MEDIUM', 'HIGH');

-- A business and an individual shouldn't automatically be judged against
-- the same activity baseline. We can use these groups for comparisons later.
-- Notice whether PEP customers appear in low or medium risk groups. If they
-- do, don't assume the existing risk rating already reflects every risk factor.


-- 2. Check whether we have transaction histories for the accounts.
-- We need activity in both directions to build inflow/outflow features.
SELECT
    COUNT(*) AS total_accounts,
    SUM(txn_count = 0) AS accounts_without_transactions,
    SUM(txn_count > 0) AS accounts_with_transactions,
    SUM(in_count > 0 AND out_count > 0) AS accounts_with_both_directions,
    SUM(in_count > 0 AND out_count = 0) AS incoming_only_accounts,
    SUM(out_count > 0 AND in_count = 0) AS outgoing_only_accounts
FROM (
    SELECT
        a.account_id,
        COUNT(t.transaction_id) AS txn_count,
        SUM(CASE WHEN t.direction = 'IN' THEN 1 ELSE 0 END) AS in_count,
        SUM(CASE WHEN t.direction = 'OUT' THEN 1 ELSE 0 END) AS out_count
    FROM accounts a
    LEFT JOIN transactions t
        ON a.account_id = t.account_id
    GROUP BY a.account_id
) AS account_activity;

-- An account with no transactions still belongs in the customer population;
-- we shouldn't lose it just because we joined to the transaction table.
-- This also tells us whether the data is varied enough to test accounts with
-- only incoming funds or only outgoing payments.


-- 3. Check how much activity is available in the last 30 days of the dataset.
-- Our reporting cutoff is the start of October 1, 2026.
WITH recent_activity AS (
    SELECT
        account_id,
        COUNT(*) AS recent_txn_count
    FROM transactions
    WHERE occurred_at >= '2026-09-01 00:00:00'
      AND occurred_at <  '2026-10-01 00:00:00'
    GROUP BY account_id
)
SELECT
    COUNT(*) AS total_accounts,
    SUM(COALESCE(r.recent_txn_count, 0) = 0) AS accounts_no_recent_activity,
    SUM(COALESCE(r.recent_txn_count, 0) BETWEEN 1 AND 4) AS accounts_1_to_4_txns,
    SUM(COALESCE(r.recent_txn_count, 0) >= 5) AS accounts_5_or_more_txns,
    SUM(a.opened_at > '2026-09-01') AS accounts_opened_during_window
FROM accounts a
LEFT JOIN recent_activity r
    ON a.account_id = r.account_id;

-- Some accounts have no September activity. That can be useful when we work
-- on inactivity or dormancy features; it is not a reason to remove them.
-- The final analysis uses a fixed October 1 snapshot. We only use
-- transactions recorded before that cutoff.


-- 4. Check whether payment channels support counterparty features.
-- Distinct counterparties help us describe how widely an account moves money.
SELECT
    channel,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT account_id) AS accounts_using_channel,
    COUNT(DISTINCT counterparty_id) AS distinct_counterparties,
    SUM(counterparty_id IS NULL) AS missing_counterparty_ids
FROM transactions
GROUP BY channel
ORDER BY channel;

-- Cash has no counterparty ID in this training data, so we can't build a
-- counterparty-diversity feature from cash transactions alone.
-- We'll calculate those features using the channels where the relationship
-- is actually recorded, rather than inventing missing counterparty values.


-- 5. Make sure the dates and profile snapshot fit our reporting period.
-- This catches obvious timing problems before we calculate historical features.
SELECT
    COUNT(*) AS transactions_checked,
    SUM(t.occurred_at < c.profile_as_of) AS before_profile_snapshot,
    SUM(t.occurred_at < c.onboarded_at) AS before_customer_onboarding,
    SUM(t.occurred_at < a.opened_at) AS before_account_opening,
    SUM(t.posted_at >= '2026-10-01 00:00:00') AS posted_after_reporting_period,
    SUM(t.occurred_at < '2026-01-01 00:00:00'
        OR t.occurred_at >= '2026-10-01 00:00:00') AS occurred_outside_reporting_period
FROM transactions t
JOIN accounts a
    ON t.account_id = a.account_id
JOIN customers c
    ON a.customer_id = c.customer_id;

-- If any date check is nonzero, we'd inspect the records before using them.
-- Even a clean result doesn't remove the risk of future-data leakage:
-- during feature engineering, every calculation must use information that
-- was available at the point in time being assessed.

-- End of feature readiness checks.
