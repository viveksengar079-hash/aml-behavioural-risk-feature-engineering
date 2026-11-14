-- Practice queries used to build and check the final features.
-- These queries only read data. Run them individually in Workbench.

USE aml_behavioural_risk_fe;

SELECT
    account_id,
    COUNT(*) AS prior_30d_txn_count
FROM transactions
WHERE account_id = 'A00662'
  AND occurred_at >= '2026-08-31'
  AND occurred_at < '2026-09-30'
  AND posted_at < '2026-10-01'
GROUP BY account_id;

-- Check how many transactions A00662 made
-- during the 30 days before September 30.
-- We will compare this with its latest 24-hour
-- activity to identify any sudden increase.



SELECT
    1 AS txn_count_24h,
    86 AS prior_30d_txn_count,

    ROUND(86 / 30.0, 2) AS avg_daily_txn,

    ROUND(
        1 / (86 / 30.0), 2
    ) AS txn_velocity_ratio;

-- Compare the latest 24-hour transaction count
-- against the earlier daily average.
-- A ratio above 1 means higher recent activity.
-- A ratio below 1 means lower recent activity.



SELECT
    account_id,

    SUM(CASE
        WHEN occurred_at >= '2026-09-30'
        THEN 1
        ELSE 0
    END) AS txn_count_24h,

    SUM(CASE
        WHEN occurred_at < '2026-09-30'
        THEN 1
        ELSE 0
    END) AS prior_30d_txn_count

FROM transactions

WHERE account_id = 'A00662'
  AND occurred_at >= '2026-08-31'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id;

-- Compare the account's latest 24-hour activity
-- with the 30 days before it.
-- Both counts now come directly from transaction records.



WITH txn_activity AS (

    SELECT
        account_id,

        SUM(CASE
            WHEN occurred_at >= '2026-09-30'
            THEN 1 ELSE 0
        END) AS txn_count_24h,

        SUM(CASE
            WHEN occurred_at < '2026-09-30'
            THEN 1 ELSE 0
        END) AS prior_30d_txn_count

    FROM transactions

    WHERE account_id = 'A00662'
      AND occurred_at >= '2026-08-31'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY account_id
)

SELECT
    account_id,
    txn_count_24h,
    prior_30d_txn_count,

    ROUND(
        txn_count_24h /
        NULLIF(prior_30d_txn_count / 30.0, 0),
        2
    ) AS txn_velocity_ratio

FROM txn_activity;

-- First, calculate recent and earlier transaction counts.
-- Then compare the latest day with the previous daily average.
-- NULLIF prevents division by zero when there is no baseline.



WITH txn_activity AS (

    SELECT
        account_id,

        SUM(CASE
            WHEN occurred_at >= '2026-09-30'
            THEN 1 ELSE 0
        END) AS txn_count_24h,

        SUM(CASE
            WHEN occurred_at < '2026-09-30'
            THEN 1 ELSE 0
        END) AS prior_30d_txn_count

    FROM transactions

    WHERE occurred_at >= '2026-08-31'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY account_id
)

SELECT
    account_id,
    txn_count_24h,
    prior_30d_txn_count,

    ROUND(
        txn_count_24h /
        NULLIF(prior_30d_txn_count / 30.0, 0),
        2
    ) AS txn_velocity_ratio

FROM txn_activity

ORDER BY txn_velocity_ratio DESC;

-- Compare each account's latest transaction activity
-- against its earlier daily average.
-- Higher ratios indicate increased transaction frequency.
-- We will review the accounts with the largest increases.



WITH txn_activity AS (

    SELECT
        a.account_id,
        a.opened_at,

        COUNT(CASE
            WHEN t.occurred_at >= '2026-09-30'
            THEN t.transaction_id
        END) AS txn_count_24h,

        COUNT(CASE
            WHEN t.occurred_at < '2026-09-30'
            THEN t.transaction_id
        END) AS prior_30d_txn_count

    FROM accounts a

    LEFT JOIN transactions t
        ON a.account_id = t.account_id
        AND t.occurred_at >= '2026-08-31'
        AND t.occurred_at < '2026-10-01'
        AND t.posted_at < '2026-10-01'

    WHERE a.opened_at < '2026-10-01'

    GROUP BY a.account_id, a.opened_at
)

SELECT
    account_id,
    txn_count_24h,
    prior_30d_txn_count,

    CASE
        WHEN opened_at > '2026-08-31'
            THEN 'INCOMPLETE_HISTORY'
        WHEN prior_30d_txn_count = 0
            THEN 'NO_BASELINE_ACTIVITY'
        WHEN prior_30d_txn_count < 5
            THEN 'LOW_BASELINE_COUNT'
        ELSE 'BASELINE_AVAILABLE'
    END AS baseline_status,

    CASE
        WHEN opened_at > '2026-08-31'
            THEN NULL
        ELSE ROUND(
            txn_count_24h /
            NULLIF(prior_30d_txn_count / 30.0, 0),
            2
        )
    END AS txn_velocity_ratio

FROM txn_activity
ORDER BY txn_velocity_ratio DESC
LIMIT 10;

-- Include accounts even if they have no recent payments.
-- Check whether enough history exists to compare activity.
-- A high ratio based on very few transactions needs caution.
-- Do not calculate a complete-window ratio for new accounts.



SELECT
    account_id,

    SUM(amount_usd) AS prior_30d_amount

FROM transactions

WHERE account_id = 'A00662'
  AND occurred_at >= '2026-08-31'
  AND occurred_at < '2026-09-30'
  AND posted_at < '2026-10-01'

GROUP BY account_id;

-- Check how much money A00662 processed in the
-- 30 days before September 30.
-- We'll compare this with the latest day's amount
-- to see whether transaction value has increased.



SELECT
    876.90 AS amount_total_24h,
    93886.27 AS prior_30d_amount,

    ROUND(
        93886.27 / 30, 2
    ) AS avg_daily_amount,

    ROUND(
        876.90 / (93886.27 / 30),
        2
    ) AS amount_spike_ratio;

-- Compare the latest day's transaction amount
-- with the average amount from the previous 30 days.
-- This tells us whether money movement has increased
-- or decreased compared with earlier activity.



WITH amount_activity AS (

    SELECT
        account_id,

        SUM(CASE
            WHEN occurred_at >= '2026-09-30'
            THEN amount_usd
            ELSE 0
        END) AS amount_total_24h,

        SUM(CASE
            WHEN occurred_at < '2026-09-30'
            THEN amount_usd
            ELSE 0
        END) AS prior_30d_amount

    FROM transactions

    WHERE account_id = 'A00662'
      AND occurred_at >= '2026-08-31'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY account_id
)

SELECT
    account_id,
    amount_total_24h,
    prior_30d_amount,

    ROUND(
        prior_30d_amount / 30,
        2
    ) AS avg_daily_amount,

    ROUND(
        amount_total_24h /
        NULLIF(prior_30d_amount / 30.0, 0),
        2
    ) AS amount_spike_ratio

FROM amount_activity;

-- First, calculate how much money moved during
-- the latest 24 hours and the previous 30 days.
-- Then compare the latest amount with the earlier
-- daily average to identify unusual changes.
-- NULLIF avoids division by zero.



WITH amount_activity AS (

    SELECT
        account_id,

        SUM(CASE
            WHEN occurred_at >= '2026-09-30'
            THEN amount_usd
            ELSE 0
        END) AS amount_total_24h,

        SUM(CASE
            WHEN occurred_at < '2026-09-30'
            THEN amount_usd
            ELSE 0
        END) AS prior_30d_amount

    FROM transactions

    WHERE occurred_at >= '2026-08-31'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY account_id
)

SELECT
    account_id,
    amount_total_24h,
    prior_30d_amount,

    ROUND(
        prior_30d_amount / 30,
        2
    ) AS avg_daily_amount,

    ROUND(
        amount_total_24h /
        NULLIF(prior_30d_amount / 30.0, 0),
        2
    ) AS amount_spike_ratio

FROM amount_activity

ORDER BY amount_spike_ratio DESC
LIMIT 10;

-- Compare each account's latest daily transaction amount
-- with its earlier daily average.
-- Show the 10 highest ratios so we can examine
-- accounts with the largest relative increases.



SELECT
    a.account_id,
    a.opened_at,

    COUNT(t.transaction_id) AS prior_30d_txn_count,

    CASE
        WHEN a.opened_at > '2026-08-31'
            THEN 'INCOMPLETE_HISTORY'

        WHEN COUNT(t.transaction_id) = 0
            THEN 'NO_BASELINE_ACTIVITY'

        WHEN COUNT(t.transaction_id) < 5
            THEN 'LOW_BASELINE_COUNT'

        ELSE 'BASELINE_AVAILABLE'
    END AS baseline_status

FROM accounts a

LEFT JOIN transactions t
    ON a.account_id = t.account_id
    AND t.occurred_at >= '2026-08-31'
    AND t.occurred_at < '2026-09-30'
    AND t.posted_at < '2026-10-01'

WHERE a.account_id IN (
    'A00245',
    'A01004',
    'A01516',
    'A01897',
    'A00367'
)

GROUP BY a.account_id, a.opened_at
ORDER BY a.account_id;

-- Check whether our highest amount spikes have
-- enough earlier transactions for a useful comparison.
-- A high ratio based on very little activity can mislead us.
-- We should review these accounts more carefully.


SELECT
    account_id,

    SUM(amount_usd) AS amount_total_30d,

    SUM(CASE
        WHEN channel = 'CASH'
        THEN amount_usd
        ELSE 0
    END) AS cash_amount_30d

FROM transactions

WHERE account_id = 'A00662'
  AND occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id;

-- Check how much of A00662's September transaction
-- amount came through cash deposits or withdrawals.
-- We'll compare this with total activity to understand
-- how heavily the account uses cash.



SELECT
    account_id,

    SUM(amount_usd) AS amount_total_30d,

    SUM(CASE
        WHEN channel = 'CASH'
        THEN amount_usd
        ELSE 0
    END) AS cash_amount_30d,

    ROUND(
        SUM(CASE
            WHEN channel = 'CASH'
            THEN amount_usd
            ELSE 0
        END) / NULLIF(SUM(amount_usd), 0),
        4
    ) AS cash_amount_share_30d

FROM transactions

WHERE account_id = 'A00662'
  AND occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id;

-- Calculate how much of the account's total
-- September transaction amount involved cash.
-- NULLIF avoids dividing by zero.



SELECT
    a.account_id,

    COALESCE(SUM(t.amount_usd), 0)
        AS amount_total_30d,

    SUM(CASE
        WHEN t.channel = 'CASH'
        THEN t.amount_usd
        ELSE 0
    END) AS cash_amount_30d,

    ROUND(
        SUM(CASE
            WHEN t.channel = 'CASH'
            THEN t.amount_usd
            ELSE 0
        END) / NULLIF(SUM(t.amount_usd), 0),
        4
    ) AS cash_amount_share_30d

FROM accounts a

LEFT JOIN transactions t
    ON a.account_id = t.account_id
    AND t.occurred_at >= '2026-09-01'
    AND t.occurred_at < '2026-10-01'
    AND t.posted_at < '2026-10-01'

WHERE a.opened_at < '2026-10-01'

GROUP BY a.account_id

ORDER BY cash_amount_share_30d DESC

LIMIT 10;

-- Calculate how much of each account's transaction
-- amount came from cash during September.
-- Keep inactive accounts in the calculation as well.
-- Show the highest cash shares first for review.



SELECT
    69323.81 AS inflow_amount_30d,
    21901.72 AS outflow_amount_30d,

    ROUND(
        21901.72 / 69323.81,
        4
    ) AS outflow_inflow_ratio_30d;

-- Compare outgoing payments with incoming funds.
-- This tells us what proportion of the money
-- received was matched by outgoing payments.



WITH fund_flow AS (

    SELECT
        account_id,

        SUM(CASE
            WHEN direction = 'IN'
            THEN amount_usd
            ELSE 0
        END) AS inflow_amount_30d,

        SUM(CASE
            WHEN direction = 'OUT'
            THEN amount_usd
            ELSE 0
        END) AS outflow_amount_30d

    FROM transactions

    WHERE account_id = 'A00662'
      AND occurred_at >= '2026-09-01'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY account_id
)

SELECT
    account_id,
    inflow_amount_30d,
    outflow_amount_30d,

    ROUND(
        outflow_amount_30d /
        NULLIF(inflow_amount_30d, 0),
        4
    ) AS outflow_inflow_ratio_30d,

    inflow_amount_30d - outflow_amount_30d
        AS net_flow_30d

FROM fund_flow;

-- First calculate how much money entered and left the account.
-- Then compare outgoing payments against incoming funds.
-- Also calculate the difference between the two amounts.
-- NULLIF prevents division by zero.



WITH fund_flow AS (

    SELECT
        a.account_id,

        SUM(CASE
            WHEN t.direction = 'IN'
            THEN t.amount_usd
            ELSE 0
        END) AS inflow_amount_30d,

        SUM(CASE
            WHEN t.direction = 'OUT'
            THEN t.amount_usd
            ELSE 0
        END) AS outflow_amount_30d

    FROM accounts a

    LEFT JOIN transactions t
        ON a.account_id = t.account_id
        AND t.occurred_at >= '2026-09-01'
        AND t.occurred_at < '2026-10-01'
        AND t.posted_at < '2026-10-01'

    WHERE a.opened_at < '2026-10-01'

    GROUP BY a.account_id
)

SELECT
    account_id,
    inflow_amount_30d,
    outflow_amount_30d,

    ROUND(
        outflow_amount_30d /
        NULLIF(inflow_amount_30d, 0),
        4
    ) AS outflow_inflow_ratio_30d,

    inflow_amount_30d - outflow_amount_30d
        AS net_flow_30d

FROM fund_flow

ORDER BY account_id;

-- Check incoming and outgoing money for every account.
-- Keep accounts even when they have no recent activity.
-- Calculate the outflow ratio and net payment flow
-- to understand differences in how funds are moving.



SELECT
    account_id,

    MAX(CASE
        WHEN occurred_at < '2026-09-30'
        THEN occurred_at
    END) AS last_txn_before_24h,

    MIN(CASE
        WHEN occurred_at >= '2026-09-30'
        THEN occurred_at
    END) AS first_txn_in_24h

FROM transactions

WHERE account_id = 'A00662'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id;

-- Find the last transaction before September 30.
-- Then find the first transaction on September 30.
-- We'll calculate the gap between these timestamps
-- to check whether the account was inactive for 60 days.



WITH txn_gap AS (

    SELECT
        account_id,

        MAX(CASE
            WHEN occurred_at < '2026-09-30'
            THEN occurred_at
        END) AS last_txn_before_24h,

        MIN(CASE
            WHEN occurred_at >= '2026-09-30'
            THEN occurred_at
        END) AS first_txn_in_24h

    FROM transactions

    WHERE account_id = 'A00662'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY account_id
)

SELECT
    account_id,

    TIMESTAMPDIFF(
        HOUR,
        last_txn_before_24h,
        first_txn_in_24h
    ) AS inactive_hours,

    TIMESTAMPDIFF(
        DAY,
        last_txn_before_24h,
        first_txn_in_24h
    ) AS inactive_days

FROM txn_gap;

-- Find how long the account was inactive before
-- its first transaction on September 30.
-- We'll check whether this gap reaches 60 full days.


WITH txn_gap AS (

    SELECT
        account_id,

        MAX(CASE
            WHEN occurred_at < '2026-09-30'
            THEN occurred_at
        END) AS previous_txn,

        MIN(CASE
            WHEN occurred_at >= '2026-09-30'
            THEN occurred_at
        END) AS recent_txn

    FROM transactions

    WHERE account_id = 'A00662'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY account_id
)

SELECT
    account_id,
    previous_txn,
    recent_txn,

    TIMESTAMPDIFF(
        DAY, previous_txn, recent_txn
    ) AS inactive_days,

    CASE
        WHEN recent_txn IS NULL THEN 0
        WHEN previous_txn IS NULL THEN NULL

        WHEN TIMESTAMPDIFF(
            DAY, previous_txn, recent_txn
        ) >= 60 THEN 1

        ELSE 0
    END AS dormant_reactivation_flag_24h

FROM txn_gap;

-- Check whether the account became active after
-- at least 60 complete days without transactions.
-- Mark it as 1 if the gap meets our threshold.
-- Don't guess when earlier transaction history is missing.



WITH txn_gap AS (

    SELECT
        a.account_id,

        MAX(CASE
            WHEN t.occurred_at < '2026-09-30'
            THEN t.occurred_at
        END) AS previous_txn,

        MIN(CASE
            WHEN t.occurred_at >= '2026-09-30'
            THEN t.occurred_at
        END) AS recent_txn

    FROM accounts a

    LEFT JOIN transactions t
        ON a.account_id = t.account_id
        AND t.occurred_at < '2026-10-01'
        AND t.posted_at < '2026-10-01'

    WHERE a.opened_at < '2026-10-01'

    GROUP BY a.account_id
)

SELECT
    account_id,
    previous_txn,
    recent_txn,

    TIMESTAMPDIFF(
        DAY, previous_txn, recent_txn
    ) AS inactive_days,

    CASE
        WHEN recent_txn IS NULL THEN 0

        WHEN previous_txn IS NULL THEN NULL

        WHEN TIMESTAMPDIFF(
            DAY, previous_txn, recent_txn
        ) >= 60 THEN 1

        ELSE 0
    END AS dormant_reactivation_flag_24h

FROM txn_gap

ORDER BY dormant_reactivation_flag_24h DESC,
         account_id;

-- Check all accounts for activity after a long gap.
-- A flag of 1 means at least 60 days passed between
-- the previous transaction and the latest day's activity.
-- Keep accounts without earlier transactions as unknown.
-- Review flagged accounts before drawing conclusions.



WITH txn_gap AS (

    SELECT
        a.account_id,

        MAX(CASE
            WHEN t.occurred_at < '2026-09-30'
            THEN t.occurred_at
        END) AS previous_txn,

        MIN(CASE
            WHEN t.occurred_at >= '2026-09-30'
            THEN t.occurred_at
        END) AS recent_txn

    FROM accounts a

    LEFT JOIN transactions t
        ON a.account_id = t.account_id
        AND t.occurred_at < '2026-10-01'
        AND t.posted_at < '2026-10-01'

    WHERE a.opened_at < '2026-10-01'

    GROUP BY a.account_id
)

SELECT
    COUNT(*) AS total_accounts,

    SUM(CASE
        WHEN recent_txn IS NULL
        THEN 1 ELSE 0
    END) AS no_recent_activity,

    SUM(CASE
        WHEN recent_txn IS NOT NULL
         AND previous_txn IS NULL
        THEN 1 ELSE 0
    END) AS unknown_history,

    SUM(CASE
        WHEN recent_txn IS NOT NULL
         AND previous_txn IS NOT NULL
         AND TIMESTAMPDIFF(
             DAY, previous_txn, recent_txn
         ) >= 60
        THEN 1 ELSE 0
    END) AS dormant_reactivation_candidates,

    SUM(CASE
        WHEN recent_txn IS NOT NULL
         AND previous_txn IS NOT NULL
         AND TIMESTAMPDIFF(
             DAY, previous_txn, recent_txn
         ) < 60
        THEN 1 ELSE 0
    END) AS recent_activity_below_60d

FROM txn_gap;

-- Summarize the dormancy results across all accounts.
-- We want to know how many accounts became active
-- after a gap of at least 60 days.
-- Keep unknown history separate instead of assuming
-- that missing information means normal activity.



WITH test_account AS (

    SELECT
        'TEST001' AS account_id,
        '2026-07-01 10:00:00' AS previous_txn,
        '2026-09-30 10:00:00' AS recent_txn
)

SELECT
    account_id,

    TIMESTAMPDIFF(
        DAY, previous_txn, recent_txn
    ) AS inactive_days,

    CASE
        WHEN TIMESTAMPDIFF(
            DAY, previous_txn, recent_txn
        ) >= 60
        THEN 1
        ELSE 0
    END AS dormant_reactivation_flag_24h

FROM test_account;

-- Test our 60-day dormancy rule with a sample account.
-- This account was inactive for more than 60 days,
-- so the rule should return 1.
-- No records are added to our actual database.



WITH test_cases AS (

    SELECT
        'TEST001' AS account_id,
        CAST('2026-07-01 10:00:00' AS DATETIME)
            AS previous_txn,
        CAST('2026-09-30 10:00:00' AS DATETIME)
            AS recent_txn

    UNION ALL

    SELECT
        'TEST002',
        '2026-09-29 10:00:00',
        '2026-09-30 10:00:00'

    UNION ALL

    SELECT
        'TEST003',
        NULL,
        '2026-09-30 10:00:00'

    UNION ALL

    SELECT
        'TEST004',
        '2026-08-01 10:00:00',
        NULL
)

SELECT
    account_id,

    CASE
        WHEN recent_txn IS NULL THEN 0
        WHEN previous_txn IS NULL THEN NULL
        WHEN TIMESTAMPDIFF(
            DAY, previous_txn, recent_txn
        ) >= 60 THEN 1
        ELSE 0
    END AS dormant_reactivation_flag_24h

FROM test_cases;

-- Test four different account activity situations.
-- This helps us check whether the dormancy rule
-- handles long gaps, short gaps and missing history.
-- These are only test values, not actual bank records.
