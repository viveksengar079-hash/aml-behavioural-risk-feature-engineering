-- Practice queries used to build and check the final features.
-- These queries only read data. Run them individually in Workbench.

USE aml_behavioural_risk_fe;

SELECT
    account_id,
    COUNT(*) AS txn_count_30d
FROM transactions
WHERE occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id
ORDER BY txn_count_30d DESC
LIMIT 10;

-- We are checking how frequently each account transacted
-- during September. Accounts with higher counts may need
-- further comparison against their normal activity.



SELECT
    COUNT(*) AS txn_count_24h
FROM transactions
WHERE account_id = 'A00662'
  AND occurred_at >= '2026-09-30 00:00:00'
  AND occurred_at < '2026-10-01 00:00:00'
  AND posted_at < '2026-10-01 00:00:00';

-- We already know this account made 85 transactions
-- in September. Now we want to see how many happened
-- during the final 24 hours.



SELECT
    account_id,
    SUM(amount_usd) AS amount_total_30d
FROM transactions
WHERE account_id = 'A00662'
  AND occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id;

-- We know this account made 85 transactions in September.
-- Now we are checking their combined dollar value.
-- This includes both incoming and outgoing payments.



SELECT
    account_id,
    SUM(amount_usd) AS inflow_amount_30d
FROM transactions
WHERE account_id = 'A00662'
  AND direction = 'IN'
  AND occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id;

-- We are checking how much money entered this account
-- during September. Later, we'll compare incoming
-- funds against outgoing payments.



SELECT
    account_id,
    SUM(amount_usd) AS outflow_amount_30d
FROM transactions
WHERE account_id = 'A00662'
  AND direction = 'OUT'
  AND occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id;

-- We are checking how much money left this account
-- during September. We will compare this amount
-- with the incoming funds to understand the flow.



SELECT
    account_id,
    SUM(amount_usd) AS amount_total_24h
FROM transactions
WHERE account_id = 'A00662'
  AND occurred_at >= '2026-09-30'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id;

-- We want to know the dollar value of transactions
-- made during the final 24 hours of September.
-- Later, we can compare this with earlier activity
-- to identify sudden increases in money movement.



SELECT
    COALESCE(SUM(amount_usd), 0) AS inflow_amount_24h
FROM transactions
WHERE account_id = 'A00662'
  AND direction = 'IN'
  AND occurred_at >= '2026-09-30'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01';

-- Check how much money entered this account
-- during the final 24 hours of September.
-- If no incoming payments exist, show zero.



SELECT
    COALESCE(SUM(amount_usd), 0) AS outflow_amount_24h
FROM transactions
WHERE account_id = 'A00662'
  AND direction = 'OUT'
  AND occurred_at >= '2026-09-30'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01';

-- Check the total outgoing amount during the
-- final 24 hours of September.
-- If no outgoing payment exists, show zero.



SELECT
    account_id,
    MAX(occurred_at) AS last_transaction_date,
    TIMESTAMPDIFF(
        DAY,
        MAX(occurred_at),
        '2026-10-01 00:00:00'
    ) AS days_since_previous_txn
FROM transactions
WHERE account_id = 'A00662'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id;

-- Find the latest transaction known before October 1.
-- Calculate how many complete days have passed since then.
-- This helps us understand how recently the account was active.


-- Calculate account activity features for all accounts


SELECT
    account_id,
    COUNT(*) AS txn_count_30d,
    SUM(amount_usd) AS amount_total_30d
FROM transactions
WHERE occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id
ORDER BY txn_count_30d DESC
LIMIT 10;

-- Calculate the number and total value of transactions
-- for each account during September.
-- Show the 10 most active accounts first.
-- This helps us compare activity across accounts.



SELECT
    account_id,
    COUNT(*) AS txn_count_30d,
    SUM(amount_usd) AS amount_total_30d,

    SUM(
        CASE
            WHEN direction = 'IN' THEN amount_usd
            ELSE 0
        END
    ) AS inflow_amount_30d

FROM transactions
WHERE occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id
ORDER BY txn_count_30d DESC
LIMIT 10;

-- We already know the total number and value of transactions.
-- Now we also want to calculate how much money each account
-- received during September.


SELECT
    account_id,
    COUNT(*) AS txn_count_30d,
    SUM(amount_usd) AS amount_total_30d,

    SUM(
        CASE
            WHEN direction = 'IN' THEN amount_usd
            ELSE 0
        END
    ) AS inflow_amount_30d,

    SUM(
        CASE
            WHEN direction = 'OUT' THEN amount_usd
            ELSE 0
        END
    ) AS outflow_amount_30d

FROM transactions
WHERE occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'
GROUP BY account_id
ORDER BY txn_count_30d DESC
LIMIT 10;

-- Check how much money each account received and sent
-- during September. Comparing both helps us understand
-- the direction of funds and overall account activity.



SELECT
    account_id,

    COUNT(*) AS txn_count_30d,

    SUM(amount_usd) AS amount_total_30d,

    SUM(CASE
        WHEN direction = 'IN' THEN amount_usd
        ELSE 0
    END) AS inflow_amount_30d,

    SUM(CASE
        WHEN direction = 'OUT' THEN amount_usd
        ELSE 0
    END) AS outflow_amount_30d,

    COUNT(CASE
        WHEN occurred_at >= '2026-09-30'
        THEN 1
    END) AS txn_count_24h,

    SUM(CASE
        WHEN occurred_at >= '2026-09-30'
        THEN amount_usd
        ELSE 0
    END) AS amount_total_24h

FROM transactions
WHERE occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id
ORDER BY txn_count_30d DESC
LIMIT 10;

-- Compare each account's September activity with its
-- final 24 hours. This helps us identify accounts
-- that may have experienced sudden changes in activity.



SELECT
    account_id,

    COUNT(*) AS txn_count_30d,
    SUM(amount_usd) AS amount_total_30d,

    SUM(CASE
        WHEN direction = 'IN' THEN amount_usd
        ELSE 0
    END) AS inflow_amount_30d,

    SUM(CASE
        WHEN direction = 'OUT' THEN amount_usd
        ELSE 0
    END) AS outflow_amount_30d,

    COUNT(CASE
        WHEN occurred_at >= '2026-09-30'
        THEN 1
    END) AS txn_count_24h,

    SUM(CASE
        WHEN occurred_at >= '2026-09-30'
        THEN amount_usd ELSE 0
    END) AS amount_total_24h,

    SUM(CASE
        WHEN occurred_at >= '2026-09-30'
         AND direction = 'IN'
        THEN amount_usd ELSE 0
    END) AS inflow_amount_24h,

    SUM(CASE
        WHEN occurred_at >= '2026-09-30'
         AND direction = 'OUT'
        THEN amount_usd ELSE 0
    END) AS outflow_amount_24h

FROM transactions
WHERE occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id
ORDER BY txn_count_30d DESC
LIMIT 10;

-- Check each account's incoming and outgoing payments
-- during the final 24 hours of September.
-- This helps us understand which direction money moved.
-- We can also check if IN + OUT matches the gross amount.



SELECT
    account_id,

    COUNT(*) AS txn_count_30d,

    SUM(amount_usd) AS amount_total_30d,

    SUM(CASE
        WHEN direction = 'IN' THEN amount_usd
        ELSE 0
    END) AS inflow_amount_30d,

    SUM(CASE
        WHEN direction = 'OUT' THEN amount_usd
        ELSE 0
    END) AS outflow_amount_30d,

    COUNT(CASE
        WHEN occurred_at >= '2026-09-30'
        THEN 1
    END) AS txn_count_24h,

    SUM(CASE
        WHEN occurred_at >= '2026-09-30'
        THEN amount_usd ELSE 0
    END) AS amount_total_24h,

    SUM(CASE
        WHEN occurred_at >= '2026-09-30'
         AND direction = 'IN'
        THEN amount_usd ELSE 0
    END) AS inflow_amount_24h,

    SUM(CASE
        WHEN occurred_at >= '2026-09-30'
         AND direction = 'OUT'
        THEN amount_usd ELSE 0
    END) AS outflow_amount_24h,

    TIMESTAMPDIFF(
        DAY,
        MAX(occurred_at),
        '2026-10-01'
    ) AS days_since_previous_txn

FROM transactions
WHERE occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id
ORDER BY txn_count_30d DESC
LIMIT 10;

-- Find how many complete days have passed since
-- each account's latest September transaction.
-- Later, we'll include older account histories
-- so we can also identify inactive accounts.



SELECT
    COUNT(DISTINCT a.account_id) AS total_accounts,

    COUNT(DISTINCT t.account_id) AS active_accounts_30d,

    COUNT(DISTINCT a.account_id)
    - COUNT(DISTINCT t.account_id) AS inactive_accounts_30d

FROM accounts a

LEFT JOIN transactions t
    ON a.account_id = t.account_id
    AND t.occurred_at >= '2026-09-01'
    AND t.occurred_at < '2026-10-01'
    AND t.posted_at < '2026-10-01'

WHERE a.opened_at < '2026-10-01';

-- Check how many accounts had transactions in September
-- and how many had no activity during that period.
-- We need both groups for reliable AML monitoring.



SELECT
    a.account_id,

    COUNT(CASE
        WHEN t.occurred_at >= '2026-09-01'
        THEN t.transaction_id
    END) AS txn_count_30d,

    SUM(CASE
        WHEN t.occurred_at >= '2026-09-01'
        THEN t.amount_usd ELSE 0
    END) AS amount_total_30d,

    SUM(CASE
        WHEN t.occurred_at >= '2026-09-01'
         AND t.direction = 'IN'
        THEN t.amount_usd ELSE 0
    END) AS inflow_amount_30d,

    SUM(CASE
        WHEN t.occurred_at >= '2026-09-01'
         AND t.direction = 'OUT'
        THEN t.amount_usd ELSE 0
    END) AS outflow_amount_30d,

    COUNT(CASE
        WHEN t.occurred_at >= '2026-09-30'
        THEN t.transaction_id
    END) AS txn_count_24h,

    SUM(CASE
        WHEN t.occurred_at >= '2026-09-30'
        THEN t.amount_usd ELSE 0
    END) AS amount_total_24h,

    SUM(CASE
        WHEN t.occurred_at >= '2026-09-30'
         AND t.direction = 'IN'
        THEN t.amount_usd ELSE 0
    END) AS inflow_amount_24h,

    SUM(CASE
        WHEN t.occurred_at >= '2026-09-30'
         AND t.direction = 'OUT'
        THEN t.amount_usd ELSE 0
    END) AS outflow_amount_24h,

    TIMESTAMPDIFF(
        DAY,
        MAX(t.occurred_at),
        '2026-10-01'
    ) AS days_since_previous_txn

FROM accounts a

LEFT JOIN transactions t
    ON a.account_id = t.account_id
    AND t.occurred_at < '2026-10-01'
    AND t.posted_at < '2026-10-01'

WHERE a.opened_at < '2026-10-01'

GROUP BY a.account_id

ORDER BY txn_count_30d DESC, a.account_id;

-- Keep every account, including those with no recent activity.
-- Calculate the September and 24-hour features separately.
-- Use all earlier transactions to find the last activity date.
-- This gives us a more complete view of account behaviour.
