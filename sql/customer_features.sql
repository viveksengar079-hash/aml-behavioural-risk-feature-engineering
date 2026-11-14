-- Practice queries used to build and check the final features.
-- These queries only read data. Run them individually in Workbench.

use aml_behavioural_risk_fe;

SELECT
    c.customer_id,
    c.customer_type,

    c.expected_monthly_txn_count,
    c.expected_monthly_turnover_usd,

    COUNT(a2.account_id) AS total_customer_accounts

FROM accounts a

JOIN customers c
    ON a.customer_id = c.customer_id

JOIN accounts a2
    ON c.customer_id = a2.customer_id
   AND a2.opened_at < '2026-10-01'

WHERE a.account_id = 'A00662'

GROUP BY
    c.customer_id,
    c.customer_type,
    c.expected_monthly_txn_count,
    c.expected_monthly_turnover_usd;

-- Find the customer who owns A00662.
-- Check their expected monthly transaction activity
-- and how many accounts they held at our snapshot date.
-- We'll use this to compare expected and actual behaviour.



SELECT
    a.customer_id,
    a.account_id,

    COUNT(t.transaction_id) AS txn_count_30d,

    ROUND(
        COALESCE(SUM(t.amount_usd), 0),
        2
    ) AS amount_total_30d

FROM accounts a

LEFT JOIN transactions t
    ON a.account_id = t.account_id
    AND t.occurred_at >= '2026-09-01'
    AND t.occurred_at < '2026-10-01'
    AND t.posted_at < '2026-10-01'

WHERE a.customer_id = 'C00542'
  AND a.opened_at < '2026-10-01'

GROUP BY
    a.customer_id,
    a.account_id

ORDER BY a.account_id;

-- Check September activity for every account
-- belonging to customer C00542.
-- Count the transactions and add their gross amounts.
-- Keep accounts even if they had no activity.
-- We'll combine these results to assess the customer.



SELECT
    c.customer_id,

    c.expected_monthly_txn_count,

    COUNT(t.transaction_id) AS actual_txn_count_30d,

    ROUND(
        COUNT(t.transaction_id) /
        NULLIF(c.expected_monthly_txn_count, 0),
        4
    ) AS txn_count_vs_expected_ratio_30d

FROM customers c

JOIN accounts a
    ON c.customer_id = a.customer_id

LEFT JOIN transactions t
    ON a.account_id = t.account_id
    AND t.occurred_at >= '2026-09-01'
    AND t.occurred_at < '2026-10-01'
    AND t.posted_at < '2026-10-01'

WHERE c.customer_id = 'C00542'
  AND a.opened_at < '2026-10-01'

GROUP BY
    c.customer_id,
    c.expected_monthly_txn_count;

-- Combine September transactions across all accounts
-- belonging to this customer.
-- Compare the actual count with the monthly activity
-- the customer was expected to perform.
-- This helps identify changes from their KYC profile.



SELECT
    c.customer_id,

    c.expected_monthly_turnover_usd,

    ROUND(
        COALESCE(SUM(t.amount_usd), 0),
        2
    ) AS actual_turnover_30d,

    ROUND(
        COALESCE(SUM(t.amount_usd), 0) /
        NULLIF(c.expected_monthly_turnover_usd, 0),
        4
    ) AS turnover_vs_expected_ratio_30d

FROM customers c

JOIN accounts a
    ON c.customer_id = a.customer_id

LEFT JOIN transactions t
    ON a.account_id = t.account_id
    AND t.occurred_at >= '2026-09-01'
    AND t.occurred_at < '2026-10-01'
    AND t.posted_at < '2026-10-01'

WHERE c.customer_id = 'C00542'
  AND a.opened_at < '2026-10-01'

GROUP BY
    c.customer_id,
    c.expected_monthly_turnover_usd;

-- Add up September transaction amounts across
-- all accounts belonging to this customer.
-- Compare the actual gross turnover with the amount
-- recorded as expected activity during KYC.
-- This helps identify changes in transaction value.



SELECT
    c.customer_id,
    c.customer_type,

    c.expected_monthly_txn_count,

    COUNT(t.transaction_id) AS actual_txn_count_30d,

    ROUND(
        COUNT(t.transaction_id) /
        NULLIF(c.expected_monthly_txn_count, 0),
        4
    ) AS txn_count_vs_expected_ratio_30d,

    c.expected_monthly_turnover_usd,

    ROUND(
        COALESCE(SUM(t.amount_usd), 0),
        2
    ) AS actual_turnover_30d,

    ROUND(
        COALESCE(SUM(t.amount_usd), 0) /
        NULLIF(c.expected_monthly_turnover_usd, 0),
        4
    ) AS turnover_vs_expected_ratio_30d

FROM customers c

LEFT JOIN accounts a
    ON c.customer_id = a.customer_id
    AND a.opened_at < '2026-10-01'

LEFT JOIN transactions t
    ON a.account_id = t.account_id
    AND t.occurred_at >= '2026-09-01'
    AND t.occurred_at < '2026-10-01'
    AND t.posted_at < '2026-10-01'

GROUP BY
    c.customer_id,
    c.customer_type,
    c.expected_monthly_txn_count,
    c.expected_monthly_turnover_usd

ORDER BY
    CASE
        WHEN c.customer_id = 'C00542' THEN 0
        ELSE 1
    END,
    c.customer_id;

-- Combine September activity across every
-- account belonging to each customer.
-- Compare actual transaction counts and gross
-- turnover with their recorded KYC expectations.
-- Keep customers even if they had no activity.
-- Show C00542 first so we can check our results.



SELECT
    COUNT(*) AS total_customers,

    COUNT(DISTINCT customer_id) AS unique_customers,

    SUM(CASE
        WHEN expected_monthly_txn_count IS NULL
        THEN 1 ELSE 0
    END) AS missing_expected_txn_count,

    SUM(CASE
        WHEN expected_monthly_txn_count = 0
        THEN 1 ELSE 0
    END) AS zero_expected_txn_count,

    SUM(CASE
        WHEN expected_monthly_turnover_usd IS NULL
        THEN 1 ELSE 0
    END) AS missing_expected_turnover,

    SUM(CASE
        WHEN expected_monthly_turnover_usd = 0
        THEN 1 ELSE 0
    END) AS zero_expected_turnover

FROM customers;

-- Check whether customer IDs are unique.
-- Look for missing or zero monthly expectations.
-- These values can affect our comparison ratios,
-- so we need to understand them before finalizing.



-- First calculate September activity directly
-- from the original transactions table.

SELECT
    'Original Transactions' AS source,

    COUNT(*) AS total_transactions,

    ROUND(SUM(t.amount_usd), 2) AS total_amount_usd

FROM transactions t

WHERE t.occurred_at >= '2026-09-01'
  AND t.occurred_at < '2026-10-01'
  AND t.posted_at < '2026-10-01'

UNION ALL

-- Now calculate the same totals after connecting
-- transactions to accounts and customers.
-- Both results should match if the joins are correct.

SELECT
    'After Customer JOINs' AS source,

    COUNT(*) AS total_transactions,

    ROUND(SUM(t.amount_usd), 2) AS total_amount_usd

FROM transactions t

JOIN accounts a
    ON t.account_id = a.account_id

JOIN customers c
    ON a.customer_id = c.customer_id

WHERE t.occurred_at >= '2026-09-01'
  AND t.occurred_at < '2026-10-01'
  AND t.posted_at < '2026-10-01'
  AND a.opened_at < '2026-10-01';
