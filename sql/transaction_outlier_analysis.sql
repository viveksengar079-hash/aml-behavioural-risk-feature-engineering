-- AML Behavioural Risk Feature Engineering
-- Transaction distribution and unusual-activity review
-- Database: aml_behavioural_risk_fe (MySQL 8.0+)
-- These queries only read data; they do not change any records.

USE aml_behavioural_risk_fe;

-- Query 1: Compare transaction amounts across payment channels.
SELECT
    channel,
    COUNT(*) AS total_transactions,
    ROUND(MIN(amount_usd), 2) AS minimum_amount,
    ROUND(AVG(amount_usd), 2) AS average_amount,
    ROUND(MAX(amount_usd), 2) AS maximum_amount
FROM transactions
GROUP BY channel
ORDER BY total_transactions DESC;

-- I am checking whether some channels normally handle larger amounts than others.
-- A big wire transfer may have a different meaning from a big card payment,
-- so we should not use one amount threshold for every channel without testing it.
-- A high maximum amount is worth reviewing, but it is not proof of a bad transaction.


-- Query 2: Check whether transactions cluster exactly at $75,000.
-- The previous review showed that every channel reached this same maximum.
SELECT
    channel,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN amount_usd = 75000 THEN 1 ELSE 0 END)
        AS transactions_at_75000,
    ROUND(
        100.0 * SUM(CASE WHEN amount_usd = 75000 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    ) AS percentage_at_75000
FROM transactions
GROUP BY channel
ORDER BY channel;

-- This checks whether $75,000 is just an occasional amount or a repeated ceiling.
-- If many payments stop at exactly this value, the synthetic data may have a cap.
-- I would document that limitation instead of treating the cap itself as an AML signal.


-- Query 3: Find the busiest account-days by number of transactions.
SELECT
    account_id,
    DATE(occurred_at) AS transaction_date,
    COUNT(*) AS daily_transaction_count,
    ROUND(SUM(amount_usd), 2) AS daily_total_amount
FROM transactions
GROUP BY account_id, DATE(occurred_at)
ORDER BY daily_transaction_count DESC, daily_total_amount DESC
LIMIT 10;

-- These are good accounts to investigate because their daily activity is high.
-- The count alone cannot tell us whether the activity is unusual for that account.
-- Next, we compare selected days with the account's earlier transaction history.


-- Query 4: Compare two high-activity account-days with the preceding 30 days.
-- The reference dates are investigation dates, not a reusable monitoring rule.
WITH selected_days AS (
    SELECT 'A01239' AS account_id, DATE('2026-07-12') AS review_date
    UNION ALL
    SELECT 'A01684', DATE('2026-07-04')
), account_activity AS (
    SELECT
        s.account_id,
        s.review_date,
        a.opened_at,
        GREATEST(
            0,
            DATEDIFF(s.review_date,
                     GREATEST(a.opened_at, DATE_SUB(s.review_date, INTERVAL 30 DAY)))
        ) AS baseline_days,
        SUM(CASE
            WHEN t.occurred_at >= DATE_SUB(s.review_date, INTERVAL 30 DAY)
             AND t.occurred_at < s.review_date
            THEN 1 ELSE 0 END) AS previous_30d_count,
        SUM(CASE
            WHEN t.occurred_at >= s.review_date
             AND t.occurred_at < DATE_ADD(s.review_date, INTERVAL 1 DAY)
            THEN 1 ELSE 0 END) AS review_day_count,
        SUM(CASE
            WHEN t.occurred_at >= s.review_date
             AND t.occurred_at < DATE_ADD(s.review_date, INTERVAL 1 DAY)
            THEN t.amount_usd ELSE 0 END) AS review_day_amount
    FROM selected_days s
    JOIN accounts a ON a.account_id = s.account_id
    LEFT JOIN transactions t
        ON t.account_id = s.account_id
       AND t.occurred_at >= DATE_SUB(s.review_date, INTERVAL 30 DAY)
       AND t.occurred_at < DATE_ADD(s.review_date, INTERVAL 1 DAY)
    GROUP BY s.account_id, s.review_date, a.opened_at
)
SELECT
    account_id,
    review_date,
    opened_at,
    baseline_days,
    previous_30d_count,
    ROUND(previous_30d_count / NULLIF(baseline_days, 0), 2)
        AS prior_daily_average,
    review_day_count,
    ROUND(review_day_amount, 2) AS review_day_amount,
    ROUND(
        review_day_count /
        NULLIF(previous_30d_count / NULLIF(baseline_days, 0), 0),
        2
    ) AS transaction_velocity_ratio
FROM account_activity
ORDER BY review_date;

-- The velocity ratio compares the review-day count with earlier daily activity.
-- For example, 40 payments versus a usual 5 per day gives a ratio of 8.
-- I have adjusted the baseline for accounts opened within the prior 30 days.
-- A NULL ratio means there is no usable earlier average, not that the risk is zero.
-- We should review customer type, counterparties and amounts before drawing conclusions.
