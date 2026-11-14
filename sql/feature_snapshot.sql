-- Build the October 1 account feature snapshot.
-- This rebuilds generated tables, not the original data.
-- Run after loading and checking the four source tables.

USE aml_behavioural_risk_fe;

SET @previous_sql_safe_updates = @@SESSION.sql_safe_updates;
SET SESSION sql_safe_updates = 0;


-- ================================================================
-- 1. START A FRESH, PHYSICAL SNAPSHOT
-- ================================================================
-- Remove only the generated working tables from an earlier attempt.
-- Leave the four source tables untouched.

DROP TABLE IF EXISTS fe_customer_totals_work;
DROP TABLE IF EXISTS fe_prior_last_work;
DROP TABLE IF EXISTS fe_recent_first_work;
DROP TABLE IF EXISTS fe_cp_24h_work;
DROP TABLE IF EXISTS fe_cp_previous_work;
DROP TABLE IF EXISTS fe_cp_recent_work;
DROP TABLE IF EXISTS fe_cp_30d_work;
DROP TABLE IF EXISTS feature_snapshot_20261001;

-- The 30 original dictionary features are explicitly named below.
-- Extra columns retain the names we used while learning, so earlier
-- examples and interview explanations still make sense.

CREATE TABLE feature_snapshot_20261001 (
    account_id VARCHAR(32) NOT NULL,
    customer_id VARCHAR(32) NOT NULL,
    customer_type VARCHAR(40),
    home_country VARCHAR(12),
    account_opened_at DATETIME,
    snapshot_date DATE NOT NULL,
    expected_monthly_txn_count INT,
    expected_monthly_turnover_usd DECIMAL(20,2),
    eligible_30d_history TINYINT NOT NULL DEFAULT 0,
    eligible_prior30d_history TINYINT NOT NULL DEFAULT 0,

    -- 01-07: transaction activity and recent history
    txn_count_24h INT NOT NULL DEFAULT 0,
    txn_count_7d INT NOT NULL DEFAULT 0,
    txn_count_30d INT NOT NULL DEFAULT 0,
    active_days_30d INT NOT NULL DEFAULT 0,
    avg_txn_per_active_day_30d DECIMAL(16,4) NULL,
    txn_velocity_ratio_24h_vs_prior30d DECIMAL(18,4) NULL,
    days_since_previous_txn INT NULL,

    -- 08-15: transaction amounts and cash
    amount_total_24h DECIMAL(20,2) NOT NULL DEFAULT 0,
    amount_total_7d DECIMAL(20,2) NOT NULL DEFAULT 0,
    amount_total_30d DECIMAL(20,2) NOT NULL DEFAULT 0,
    avg_amount_30d DECIMAL(20,2) NULL,
    max_amount_30d DECIMAL(20,2) NULL,
    amount_spike_ratio_24h_vs_prior30d DECIMAL(18,4) NULL,
    round_amount_count_30d INT NOT NULL DEFAULT 0,
    cash_amount_share_30d DECIMAL(12,4) NULL,

    -- 16-21: money coming in and moving out
    inflow_amount_24h DECIMAL(20,2) NOT NULL DEFAULT 0,
    outflow_amount_24h DECIMAL(20,2) NOT NULL DEFAULT 0,
    inflow_amount_30d DECIMAL(20,2) NOT NULL DEFAULT 0,
    outflow_amount_30d DECIMAL(20,2) NOT NULL DEFAULT 0,
    outflow_inflow_ratio_30d DECIMAL(18,4) NULL,
    net_flow_30d DECIMAL(20,2) NOT NULL DEFAULT 0,

    -- 22-26: known-counterparty relationships
    unique_counterparties_7d INT NOT NULL DEFAULT 0,
    unique_counterparties_30d INT NOT NULL DEFAULT 0,
    new_counterparty_share_7d DECIMAL(12,4) NULL,
    top_counterparty_concentration_30d DECIMAL(12,4) NULL,
    repeated_counterparty_max_count_24h INT NOT NULL DEFAULT 0,

    -- 27-30: KYC expectations, country and dormancy
    expected_count_ratio_30d DECIMAL(18,4) NULL,
    inflow_vs_expected_turnover_ratio_30d DECIMAL(18,4) NULL,
    country_mismatch_share_30d DECIMAL(12,4) NULL,
    dormant_reactivation_flag_24h TINYINT NULL,

    -- Useful supporting values; these are not additional dictionary features.
    cash_amount_30d DECIMAL(20,2) NOT NULL DEFAULT 0,
    known_counterparty_txn_count_30d INT NOT NULL DEFAULT 0,
    country_mismatch_count_30d INT NOT NULL DEFAULT 0,
    missing_country_details_30d INT NOT NULL DEFAULT 0,
    actual_customer_txn_count_30d INT NOT NULL DEFAULT 0,
    actual_customer_turnover_30d DECIMAL(20,2) NOT NULL DEFAULT 0,
    actual_customer_inflow_30d DECIMAL(20,2) NOT NULL DEFAULT 0,
    txn_count_vs_expected_ratio_30d DECIMAL(18,4) NULL,
    turnover_vs_expected_ratio_30d DECIMAL(18,4) NULL,
    txn_velocity_ratio DECIMAL(18,4) NULL,
    amount_spike_ratio DECIMAL(18,4) NULL,

    PRIMARY KEY (account_id),
    INDEX ix_snapshot_customer (customer_id)
) ENGINE=InnoDB;

-- Start from ALL accounts existing before our snapshot cutoff.
-- This also keeps accounts that had no September activity.
INSERT INTO feature_snapshot_20261001 (
    account_id, customer_id, customer_type, home_country,
    account_opened_at, snapshot_date,
    expected_monthly_txn_count, expected_monthly_turnover_usd,
    eligible_30d_history, eligible_prior30d_history
)
SELECT
    a.account_id,
    a.customer_id,
    c.customer_type,
    c.home_country,
    a.opened_at,
    '2026-10-01',
    c.expected_monthly_txn_count,
    c.expected_monthly_turnover_usd,
    CASE WHEN a.opened_at <= '2026-09-01' THEN 1 ELSE 0 END,
    CASE WHEN a.opened_at <= '2026-08-31' THEN 1 ELSE 0 END
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id
WHERE a.opened_at < '2026-10-01';

-- EXPECTED: 2135 accounts and 2135 unique account IDs.
SELECT COUNT(*) AS accounts_loaded,
       COUNT(DISTINCT account_id) AS unique_account_ids
FROM feature_snapshot_20261001;


-- ================================================================
-- 2. SEPTEMBER ACTIVITY, AMOUNTS AND IN/OUT FLOW
-- ================================================================
-- One grouped scan calculates all simple 30d/7d/24h features.
-- This is much easier on MySQL than repeatedly reopening nested views.
-- Accounts with no transactions keep the zero defaults from Section 1.

UPDATE feature_snapshot_20261001 f
JOIN (
    SELECT
        account_id,
        COUNT(*) AS cnt_30d,
        SUM(CASE WHEN occurred_at >= '2026-09-24' THEN 1 ELSE 0 END) AS cnt_7d,
        SUM(CASE WHEN occurred_at >= '2026-09-30' THEN 1 ELSE 0 END) AS cnt_24h,
        COUNT(DISTINCT DATE(occurred_at)) AS active_days,
        ROUND(SUM(amount_usd), 2) AS gross_30d,
        ROUND(SUM(CASE WHEN occurred_at >= '2026-09-24' THEN amount_usd ELSE 0 END), 2) AS gross_7d,
        ROUND(SUM(CASE WHEN occurred_at >= '2026-09-30' THEN amount_usd ELSE 0 END), 2) AS gross_24h,
        ROUND(AVG(amount_usd), 2) AS avg_amount,
        ROUND(MAX(amount_usd), 2) AS max_amount,
        SUM(CASE WHEN amount_usd > 0 AND MOD(amount_usd, 1000) = 0 THEN 1 ELSE 0 END) AS round_count,
        ROUND(SUM(CASE WHEN direction = 'IN' THEN amount_usd ELSE 0 END), 2) AS inflow_30d,
        ROUND(SUM(CASE WHEN direction = 'OUT' THEN amount_usd ELSE 0 END), 2) AS outflow_30d,
        ROUND(SUM(CASE WHEN direction = 'IN' AND occurred_at >= '2026-09-30'
                       THEN amount_usd ELSE 0 END), 2) AS inflow_24h,
        ROUND(SUM(CASE WHEN direction = 'OUT' AND occurred_at >= '2026-09-30'
                       THEN amount_usd ELSE 0 END), 2) AS outflow_24h,
        ROUND(SUM(CASE WHEN counterparty_id IS NULL THEN amount_usd ELSE 0 END), 2) AS cash_30d
    FROM transactions
    WHERE occurred_at >= '2026-09-01'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'
    GROUP BY account_id
) x ON f.account_id = x.account_id
SET
    f.txn_count_30d = x.cnt_30d,
    f.txn_count_7d = x.cnt_7d,
    f.txn_count_24h = x.cnt_24h,
    f.active_days_30d = x.active_days,
    f.avg_txn_per_active_day_30d = ROUND(x.cnt_30d / NULLIF(x.active_days, 0), 4),
    f.amount_total_30d = x.gross_30d,
    f.amount_total_7d = x.gross_7d,
    f.amount_total_24h = x.gross_24h,
    f.avg_amount_30d = x.avg_amount,
    f.max_amount_30d = x.max_amount,
    f.round_amount_count_30d = x.round_count,
    f.inflow_amount_24h = x.inflow_24h,
    f.outflow_amount_24h = x.outflow_24h,
    f.inflow_amount_30d = x.inflow_30d,
    f.outflow_amount_30d = x.outflow_30d,
    f.net_flow_30d = x.inflow_30d - x.outflow_30d,
    f.outflow_inflow_ratio_30d = ROUND(x.outflow_30d / NULLIF(x.inflow_30d, 0), 4),
    f.cash_amount_30d = x.cash_30d,
    f.cash_amount_share_30d = ROUND(x.cash_30d / NULLIF(x.gross_30d, 0), 4);

-- We use counterparty_id IS NULL as the cash indicator because our
-- synthetic dataset was checked for that rule. Do not assume this in
-- a real bank without checking the transaction channel as well.


-- ================================================================
-- 3. TRANSACTION HISTORY AND SPIKE RATIOS
-- ================================================================
-- Days since the most recent known transaction BEFORE the snapshot.
-- For A00662 the last transaction was on September 30, so this is 0
-- complete elapsed days. No known transaction history stays NULL.

UPDATE feature_snapshot_20261001 f
JOIN (
    SELECT account_id, MAX(occurred_at) AS latest_txn
    FROM transactions
    WHERE occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'
    GROUP BY account_id
) x ON f.account_id = x.account_id
SET f.days_since_previous_txn = TIMESTAMPDIFF(DAY, x.latest_txn, '2026-10-01');

-- Compare September 30 with August 31 through September 29.
-- New accounts without a complete previous 30-day observation period
-- keep a NULL ratio, even if they have some earlier transactions.
UPDATE feature_snapshot_20261001 f
JOIN (
    SELECT
        account_id,
        COUNT(*) AS prior_count,
        ROUND(SUM(amount_usd), 2) AS prior_amount
    FROM transactions
    WHERE occurred_at >= '2026-08-31'
      AND occurred_at < '2026-09-30'
      AND posted_at < '2026-10-01'
    GROUP BY account_id
) x ON f.account_id = x.account_id
SET
    f.txn_velocity_ratio_24h_vs_prior30d =
        CASE WHEN f.eligible_prior30d_history = 1
             THEN ROUND(f.txn_count_24h * 30.0 / NULLIF(x.prior_count, 0), 4)
             ELSE NULL END,
    f.amount_spike_ratio_24h_vs_prior30d =
        CASE WHEN f.eligible_prior30d_history = 1
             THEN ROUND(f.amount_total_24h * 30.0 / NULLIF(x.prior_amount, 0), 4)
             ELSE NULL END;

-- Keep the short, two-decimal values used in earlier Workbench examples.
-- The formal dictionary columns retain four decimals for later analysis.
UPDATE feature_snapshot_20261001
SET txn_velocity_ratio = ROUND(txn_velocity_ratio_24h_vs_prior30d, 2),
    amount_spike_ratio = ROUND(amount_spike_ratio_24h_vs_prior30d, 2);


-- ================================================================
-- 4. COUNTERPARTY ACTIVITY IN SEPTEMBER
-- ================================================================
-- First save one small row per account-counterparty relationship.
-- This gives us distinct counterparties, concentration and country
-- mismatch without running the same large joins again and again.

CREATE TABLE fe_cp_30d_work AS
SELECT
    t.account_id,
    t.counterparty_id,
    COUNT(*) AS txn_count,
    ROUND(SUM(t.amount_usd), 2) AS gross_amount,
    SUM(CASE
        WHEN p.registration_country IS NOT NULL
         AND TRIM(p.registration_country) <> ''
         AND c.home_country IS NOT NULL
         AND TRIM(c.home_country) <> ''
         AND UPPER(TRIM(p.registration_country)) <> UPPER(TRIM(c.home_country))
        THEN 1 ELSE 0 END) AS mismatch_count,
    SUM(CASE
        WHEN p.counterparty_id IS NULL
          OR p.registration_country IS NULL
          OR TRIM(p.registration_country) = ''
          OR c.home_country IS NULL
          OR TRIM(c.home_country) = ''
        THEN 1 ELSE 0 END) AS missing_country_count
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
LEFT JOIN counterparties p ON t.counterparty_id = p.counterparty_id
WHERE t.counterparty_id IS NOT NULL
  AND t.occurred_at >= '2026-09-01'
  AND t.occurred_at < '2026-10-01'
  AND t.posted_at < '2026-10-01'
GROUP BY t.account_id, t.counterparty_id;

CREATE INDEX ix_cp_30d_account ON fe_cp_30d_work (account_id);

UPDATE feature_snapshot_20261001 f
JOIN (
    SELECT
        account_id,
        COUNT(*) AS unique_parties,
        SUM(txn_count) AS known_party_txns,
        MAX(gross_amount) AS largest_party_amount,
        SUM(gross_amount) AS all_party_amount,
        SUM(mismatch_count) AS mismatched_txns,
        SUM(missing_country_count) AS missing_country_txns
    FROM fe_cp_30d_work
    GROUP BY account_id
) x ON f.account_id = x.account_id
SET
    f.unique_counterparties_30d = x.unique_parties,
    f.known_counterparty_txn_count_30d = x.known_party_txns,
    f.top_counterparty_concentration_30d =
        ROUND(x.largest_party_amount / NULLIF(x.all_party_amount, 0), 4),
    f.country_mismatch_count_30d = x.mismatched_txns,
    f.missing_country_details_30d = x.missing_country_txns,
    f.country_mismatch_share_30d =
        CASE WHEN x.missing_country_txns > 0 THEN NULL
             ELSE ROUND(x.mismatched_txns / NULLIF(x.known_party_txns, 0), 4)
        END;

-- With no known counterparties, the counts stay zero and the
-- concentration/country ratios stay NULL. That is intentional.


-- ================================================================
-- 5. NEW COUNTERPARTY SHARE OVER THE LAST 7 DAYS
-- ================================================================
-- Compare each distinct counterparty seen on September 24-30 with
-- those seen during August 25-September 23. Cash has no counterparty.

CREATE TABLE fe_cp_recent_work AS
SELECT DISTINCT account_id, counterparty_id
FROM transactions
WHERE counterparty_id IS NOT NULL
  AND occurred_at >= '2026-09-24'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01';

CREATE TABLE fe_cp_previous_work AS
SELECT DISTINCT account_id, counterparty_id
FROM transactions
WHERE counterparty_id IS NOT NULL
  AND occurred_at >= '2026-08-25'
  AND occurred_at < '2026-09-24'
  AND posted_at < '2026-10-01';

CREATE INDEX ix_cp_recent_pair ON fe_cp_recent_work (account_id, counterparty_id);
CREATE INDEX ix_cp_previous_pair ON fe_cp_previous_work (account_id, counterparty_id);

UPDATE feature_snapshot_20261001 f
JOIN (
    SELECT
        r.account_id,
        COUNT(*) AS recent_parties,
        SUM(CASE WHEN p.counterparty_id IS NULL THEN 1 ELSE 0 END) AS new_parties
    FROM fe_cp_recent_work r
    LEFT JOIN fe_cp_previous_work p
      ON r.account_id = p.account_id
     AND r.counterparty_id = p.counterparty_id
    GROUP BY r.account_id
) x ON f.account_id = x.account_id
SET
    f.unique_counterparties_7d = x.recent_parties,
    f.new_counterparty_share_7d =
        CASE WHEN f.account_opened_at <= '2026-08-25'
             THEN ROUND(x.new_parties / NULLIF(x.recent_parties, 0), 4)
             ELSE NULL END;

-- If an account has no recent counterparties, its count remains 0
-- and its new-counterparty share remains NULL, not a guessed 0%.


-- ================================================================
-- 6. REPEATED COUNTERPARTY ACTIVITY IN THE LAST 24 HOURS
-- ================================================================

CREATE TABLE fe_cp_24h_work AS
SELECT
    account_id,
    counterparty_id,
    COUNT(*) AS repeat_count
FROM transactions
WHERE counterparty_id IS NOT NULL
  AND occurred_at >= '2026-09-30'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id, counterparty_id;

UPDATE feature_snapshot_20261001 f
JOIN (
    SELECT account_id, MAX(repeat_count) AS largest_repeat_count
    FROM fe_cp_24h_work
    GROUP BY account_id
) x ON f.account_id = x.account_id
SET f.repeated_counterparty_max_count_24h = x.largest_repeat_count;

-- A value of 1 is one transaction with a counterparty, NOT repetition.
-- Accounts with no known-counterparty activity keep their zero default.


-- ================================================================
-- 7. DORMANT ACCOUNT REACTIVATION
-- ================================================================
-- Find the first transaction on September 30 and the most recent
-- transaction BEFORE September 30. This avoids a slow per-account
-- search through the entire transactions table.

CREATE TABLE fe_recent_first_work AS
SELECT account_id, MIN(occurred_at) AS first_recent_txn
FROM transactions
WHERE occurred_at >= '2026-09-30'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id;

CREATE TABLE fe_prior_last_work AS
SELECT account_id, MAX(occurred_at) AS last_prior_txn
FROM transactions
WHERE occurred_at < '2026-09-30'
  AND posted_at < '2026-10-01'
GROUP BY account_id;

CREATE INDEX ix_recent_first_account ON fe_recent_first_work (account_id);
CREATE INDEX ix_prior_last_account ON fe_prior_last_work (account_id);

UPDATE feature_snapshot_20261001 f
LEFT JOIN fe_recent_first_work r ON f.account_id = r.account_id
LEFT JOIN fe_prior_last_work p ON f.account_id = p.account_id
SET f.dormant_reactivation_flag_24h =
    CASE
        WHEN r.first_recent_txn IS NULL THEN 0
        WHEN f.account_opened_at > DATE_SUB(r.first_recent_txn, INTERVAL 60 DAY) THEN NULL
        WHEN p.last_prior_txn IS NULL THEN NULL
        WHEN TIMESTAMPDIFF(DAY, p.last_prior_txn, r.first_recent_txn) >= 60 THEN 1
        ELSE 0
    END;

-- A recently opened account cannot establish a 60-day dormant spell.
-- No recent activity means no reactivation (0); unknown prior history
-- for an active account is kept as NULL rather than invented.


-- ================================================================
-- 8. CUSTOMER-LEVEL EXPECTED ACTIVITY
-- ================================================================
-- Combine every customer's account figures ONCE in a small work table.
-- Then attach the same customer-level measures to each of their accounts.
-- Do not sum these customer figures again across account rows in Python!

CREATE TABLE fe_customer_totals_work AS
SELECT
    customer_id,
    SUM(txn_count_30d) AS actual_customer_count,
    ROUND(SUM(amount_total_30d), 2) AS actual_customer_gross,
    ROUND(SUM(inflow_amount_30d), 2) AS actual_customer_inflow
FROM feature_snapshot_20261001
GROUP BY customer_id;

CREATE UNIQUE INDEX ix_customer_totals ON fe_customer_totals_work (customer_id);

UPDATE feature_snapshot_20261001 f
JOIN fe_customer_totals_work x ON f.customer_id = x.customer_id
SET
    f.actual_customer_txn_count_30d = x.actual_customer_count,
    f.actual_customer_turnover_30d = x.actual_customer_gross,
    f.actual_customer_inflow_30d = x.actual_customer_inflow,
    f.expected_count_ratio_30d =
        ROUND(x.actual_customer_count / NULLIF(f.expected_monthly_txn_count, 0), 4),
    f.txn_count_vs_expected_ratio_30d =
        ROUND(x.actual_customer_count / NULLIF(f.expected_monthly_txn_count, 0), 4),
    f.inflow_vs_expected_turnover_ratio_30d =
        ROUND(x.actual_customer_inflow / NULLIF(f.expected_monthly_turnover_usd, 0), 4),
    f.turnover_vs_expected_ratio_30d =
        ROUND(x.actual_customer_gross / NULLIF(f.expected_monthly_turnover_usd, 0), 4);

-- Dictionary feature #28 uses INFLOW / expected turnover.
-- Our earlier learning exercise used GROSS / expected turnover instead.
-- Both are retained and named clearly; they are not interchangeable.
-- In a real investigation, verify what 'expected turnover' actually means.


-- ================================================================
-- 9. FINAL QUALITY CHECKS: RUN THESE AND EXAMINE THE RESULTS
-- ================================================================
-- These SELECT statements read the finished physical table.
-- They should be much lighter than queries against our old view chain.

-- CHECK A: basic coverage and financial reconciliation.
-- EXPECTED: 2135 | 2135 | 1700 | 18846 | 27315157.30 | 27315157.30
SELECT
    COUNT(*) AS total_accounts,
    COUNT(DISTINCT account_id) AS unique_accounts,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(txn_count_30d) AS september_transactions,
    ROUND(SUM(amount_total_30d), 2) AS september_gross_usd,
    ROUND(SUM(inflow_amount_30d + outflow_amount_30d), 2) AS inflow_plus_outflow_usd
FROM feature_snapshot_20261001;

-- CHECK B: make sure no accounts or windows were corrupted.
-- EXPECTED: 0 invalid counts, 0 invalid money flows, 0 invalid ratios.
SELECT
    SUM(CASE WHEN txn_count_24h > txn_count_7d
                  OR txn_count_7d > txn_count_30d
                  OR active_days_30d > 30
                  OR active_days_30d > txn_count_30d
                  OR (txn_count_30d > 0 AND active_days_30d = 0)
             THEN 1 ELSE 0 END) AS invalid_activity_windows,
    SUM(CASE WHEN amount_total_24h > amount_total_7d
                  OR amount_total_7d > amount_total_30d
                  OR ABS(amount_total_30d - inflow_amount_30d - outflow_amount_30d) > 0.01
             THEN 1 ELSE 0 END) AS invalid_amounts_or_flows,
    SUM(CASE WHEN unique_counterparties_7d > unique_counterparties_30d
             THEN 1 ELSE 0 END) AS invalid_counterparty_counts,
    SUM(CASE WHEN (cash_amount_share_30d < 0 OR cash_amount_share_30d > 1)
                  OR (new_counterparty_share_7d < 0 OR new_counterparty_share_7d > 1)
                  OR (top_counterparty_concentration_30d < 0 OR top_counterparty_concentration_30d > 1)
                  OR (country_mismatch_share_30d < 0 OR country_mismatch_share_30d > 1)
             THEN 1 ELSE 0 END) AS invalid_shares,
    SUM(missing_country_details_30d) AS transactions_with_missing_country_details
FROM feature_snapshot_20261001;

-- CHECK C: expected missing-value counts.
-- Earlier investigations found 25 accounts with no September transactions,
-- 32 accounts with no known September counterparties, and 456 NULL new-party
-- shares. Historical eligibility may change some baseline NULL counts.
SELECT
    SUM(CASE WHEN txn_count_30d = 0 THEN 1 ELSE 0 END) AS accounts_no_september_txns,
    SUM(CASE WHEN unique_counterparties_30d = 0 THEN 1 ELSE 0 END) AS accounts_no_known_parties,
    SUM(CASE WHEN new_counterparty_share_7d IS NULL THEN 1 ELSE 0 END) AS null_new_party_shares,
    SUM(CASE WHEN top_counterparty_concentration_30d IS NULL THEN 1 ELSE 0 END) AS null_concentration,
    SUM(CASE WHEN country_mismatch_share_30d IS NULL THEN 1 ELSE 0 END) AS null_country_share,
    SUM(CASE WHEN txn_velocity_ratio_24h_vs_prior30d IS NULL THEN 1 ELSE 0 END) AS null_velocity,
    SUM(CASE WHEN amount_spike_ratio_24h_vs_prior30d IS NULL THEN 1 ELSE 0 END) AS null_spike,
    SUM(CASE WHEN expected_count_ratio_30d IS NULL THEN 1 ELSE 0 END) AS null_expected_count_ratio
FROM feature_snapshot_20261001;

-- CHECK D: familiar account. These are the results established in our exercises:
-- A00662 / C00542 / 85 txns / $91225.53 gross / 5 recent-7d txns /
-- 1 last-day txn / $876.90 last-day gross / 0.3500 velocity / 0.2800 spike /
-- $69323.81 inflow / $21901.72 outflow / $47422.09 net /
-- $4740.48 cash / 0.0520 share / 3 seven-day parties / 70 monthly parties /
-- 0.3333 new-party share / 0.0756 largest-party share / 1 repeat /
-- 0.0000 country mismatch / 2.6571 customer count ratio /
-- 1.0795 customer GROSS turnover ratio.
SELECT
    account_id, customer_id, txn_count_30d, txn_count_7d, txn_count_24h,
    amount_total_30d, amount_total_24h,
    inflow_amount_30d, outflow_amount_30d, net_flow_30d,
    cash_amount_30d, cash_amount_share_30d,
    txn_velocity_ratio, amount_spike_ratio,
    unique_counterparties_7d, unique_counterparties_30d,
    new_counterparty_share_7d, top_counterparty_concentration_30d,
    repeated_counterparty_max_count_24h, country_mismatch_share_30d,
    txn_count_vs_expected_ratio_30d, turnover_vs_expected_ratio_30d,
    dormant_reactivation_flag_24h, days_since_previous_txn,
    active_days_30d, avg_txn_per_active_day_30d,
    avg_amount_30d, max_amount_30d, round_amount_count_30d
FROM feature_snapshot_20261001
WHERE account_id = 'A00662';

-- CHECK E: all customer-level figures should match across this customer's
-- two accounts. DO NOT add these two rows together; that would double-count.
-- EXPECTED both: 93 / 2.6571 / 102556.61 / 1.0795
SELECT
    account_id, customer_id,
    actual_customer_txn_count_30d,
    expected_count_ratio_30d,
    actual_customer_turnover_30d,
    turnover_vs_expected_ratio_30d,
    actual_customer_inflow_30d,
    inflow_vs_expected_turnover_ratio_30d
FROM feature_snapshot_20261001
WHERE customer_id = 'C00542'
ORDER BY account_id;

-- CHECK F: samples with known counterparty activity.
-- A00069 should have a 1.0000 country mismatch ratio.
-- A00033 should have a 0.3750 country mismatch ratio.
-- A00800 and A01254 should each show repeat count 3.
-- A00001 should have zero known counterparties and NULL concentration.
SELECT
    account_id,
    unique_counterparties_30d,
    country_mismatch_share_30d,
    repeated_counterparty_max_count_24h,
    top_counterparty_concentration_30d
FROM feature_snapshot_20261001
WHERE account_id IN ('A00001','A00033','A00069','A00800','A01254')
ORDER BY account_id;

-- CHECK G: verify all 30 original dictionary feature names are present.
-- EXPECTED: 30
SELECT COUNT(*) AS dictionary_features_present
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'feature_snapshot_20261001'
  AND COLUMN_NAME IN (
    'txn_count_24h', 'txn_count_7d', 'txn_count_30d',
    'active_days_30d', 'avg_txn_per_active_day_30d',
    'txn_velocity_ratio_24h_vs_prior30d', 'days_since_previous_txn',
    'amount_total_24h', 'amount_total_7d', 'amount_total_30d',
    'avg_amount_30d', 'max_amount_30d',
    'amount_spike_ratio_24h_vs_prior30d', 'round_amount_count_30d',
    'cash_amount_share_30d', 'inflow_amount_24h', 'outflow_amount_24h',
    'inflow_amount_30d', 'outflow_amount_30d',
    'outflow_inflow_ratio_30d', 'net_flow_30d',
    'unique_counterparties_7d', 'unique_counterparties_30d',
    'new_counterparty_share_7d', 'top_counterparty_concentration_30d',
    'repeated_counterparty_max_count_24h',
    'expected_count_ratio_30d', 'inflow_vs_expected_turnover_ratio_30d',
    'country_mismatch_share_30d', 'dormant_reactivation_flag_24h'
  );

-- CHECK H: independently reconcile the source records with the snapshot.
-- Both rows should have 18846 transactions and $27315157.30 gross.
SELECT
    'source_transactions' AS source_name,
    COUNT(*) AS txn_count,
    ROUND(SUM(amount_usd), 2) AS gross_amount_usd
FROM transactions
WHERE occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
UNION ALL
SELECT
    'physical_snapshot',
    SUM(txn_count_30d),
    ROUND(SUM(amount_total_30d), 2)
FROM feature_snapshot_20261001;

-- FINAL TABLE TO USE IN PYTHON AFTER VALIDATION:
-- SELECT * FROM feature_snapshot_20261001;
--
-- We deliberately keep fe_*_work tables until validation is complete.
-- They are small and can be inspected if a check fails.
-- Rerunning this file rebuilds them safely, without touching source tables.

SET SESSION sql_safe_updates = @previous_sql_safe_updates;
