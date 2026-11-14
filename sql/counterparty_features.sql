-- Practice queries used to build and check the final features.
-- These queries only read data. Run them individually in Workbench.

USE aml_behavioural_risk_fe;

SELECT
    account_id,

    COUNT(*) AS txn_count_30d,

    COUNT(DISTINCT counterparty_id)
        AS unique_counterparties_30d

FROM transactions

WHERE account_id = 'A00662'
  AND occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id;

-- Check how many different counterparties A00662
-- interacted with during September.
-- Repeated transactions with the same counterparty
-- should count as only one unique counterparty.
-- Cash transactions have no counterparty ID,
-- so COUNT DISTINCT excludes those NULL values.



SELECT
    account_id,

    COUNT(*) AS txn_count_7d,

    COUNT(DISTINCT counterparty_id)
        AS unique_counterparties_7d

FROM transactions

WHERE account_id = 'A00662'
  AND occurred_at >= '2026-09-24'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id;

-- Check how many transactions A00662 made
-- during the final seven days of September.
-- Also count how many different counterparties
-- were involved in those transactions.
-- Cash transactions remain in the transaction count,
-- but their NULL counterparties are not counted.



SELECT
    account_id,

    COUNT(DISTINCT counterparty_id)
        AS unique_counterparties_30d,

    COUNT(DISTINCT CASE
        WHEN occurred_at >= '2026-09-24'
        THEN counterparty_id
    END) AS unique_counterparties_7d

FROM transactions

WHERE account_id = 'A00662'
  AND occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id;

-- Count the different counterparties involved
-- during September and during its final seven days.
-- This lets us compare recent counterparty activity
-- without running two separate queries.



SELECT
    a.account_id,

    COUNT(DISTINCT t.counterparty_id)
        AS unique_counterparties_30d,

    COUNT(DISTINCT CASE
        WHEN t.occurred_at >= '2026-09-24'
        THEN t.counterparty_id
    END) AS unique_counterparties_7d

FROM accounts a

LEFT JOIN transactions t
    ON a.account_id = t.account_id
    AND t.occurred_at >= '2026-09-01'
    AND t.occurred_at < '2026-10-01'
    AND t.posted_at < '2026-10-01'

WHERE a.opened_at < '2026-10-01'

GROUP BY a.account_id

ORDER BY a.account_id;

-- Check how many different counterparties each account
-- interacted with over the last 7 and 30 days.
-- Keep accounts with no transactions in our results.
-- Cash transactions have no known counterparty ID,
-- so they are not included in these counts.



SELECT
    account_id,

    COUNT(DISTINCT counterparty_id)
        AS prior_30d_unique_counterparties

FROM transactions

WHERE account_id = 'A00662'
  AND occurred_at >= '2026-08-25'
  AND occurred_at < '2026-09-24'
  AND posted_at < '2026-10-01'

GROUP BY account_id;

-- Check how many different counterparties A00662
-- interacted with before the latest seven days.
-- We'll compare these earlier relationships with
-- recent counterparties to identify new ones.



WITH recent_counterparties AS (

    SELECT DISTINCT counterparty_id
    FROM transactions
    WHERE account_id = 'A00662'
      AND occurred_at >= '2026-09-24'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'
      AND counterparty_id IS NOT NULL
),

previous_counterparties AS (

    SELECT DISTINCT counterparty_id
    FROM transactions
    WHERE account_id = 'A00662'
      AND occurred_at >= '2026-08-25'
      AND occurred_at < '2026-09-24'
      AND posted_at < '2026-10-01'
      AND counterparty_id IS NOT NULL
)

SELECT
    r.counterparty_id,

    CASE
        WHEN p.counterparty_id IS NULL
        THEN 'NEW'
        ELSE 'EXISTING'
    END AS counterparty_status

FROM recent_counterparties r

LEFT JOIN previous_counterparties p
    ON r.counterparty_id = p.counterparty_id

ORDER BY r.counterparty_id;

-- Compare recent counterparties with those seen earlier.
-- If a recent counterparty is missing from the earlier
-- list, mark it as NEW. Otherwise mark it EXISTING.



SELECT
    1 AS new_counterparties,
    3 AS total_recent_counterparties,

    ROUND(
        1 / 3.0,
        4
    ) AS new_counterparty_share_7d;

-- One of the three recent counterparties was not
-- seen during the previous 30 days.
-- Calculate the share of new relationships.



WITH recent_counterparties AS (

    SELECT DISTINCT counterparty_id
    FROM transactions
    WHERE account_id = 'A00662'
      AND occurred_at >= '2026-09-24'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'
      AND counterparty_id IS NOT NULL
),

previous_counterparties AS (

    SELECT DISTINCT counterparty_id
    FROM transactions
    WHERE account_id = 'A00662'
      AND occurred_at >= '2026-08-25'
      AND occurred_at < '2026-09-24'
      AND posted_at < '2026-10-01'
      AND counterparty_id IS NOT NULL
)

SELECT
    COUNT(*) AS total_recent_counterparties,

    SUM(CASE
        WHEN p.counterparty_id IS NULL
        THEN 1 ELSE 0
    END) AS new_counterparties,

    ROUND(
        SUM(CASE
            WHEN p.counterparty_id IS NULL
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        4
    ) AS new_counterparty_share_7d

FROM recent_counterparties r

LEFT JOIN previous_counterparties p
    ON r.counterparty_id = p.counterparty_id;

-- Compare recent counterparties with the earlier list.
-- Count those not seen during the previous 30 days.
-- Divide that count by all recent unique counterparties.
-- This calculates the new-party share automatically.



WITH recent AS (

    SELECT DISTINCT
        account_id,
        counterparty_id
    FROM transactions
    WHERE occurred_at >= '2026-09-24'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'
      AND counterparty_id IS NOT NULL
),

previous AS (

    SELECT DISTINCT
        account_id,
        counterparty_id
    FROM transactions
    WHERE occurred_at >= '2026-08-25'
      AND occurred_at < '2026-09-24'
      AND posted_at < '2026-10-01'
      AND counterparty_id IS NOT NULL
)

SELECT
    a.account_id,

    COUNT(r.counterparty_id)
        AS total_recent_counterparties,

    SUM(CASE
        WHEN r.counterparty_id IS NOT NULL
         AND p.counterparty_id IS NULL
        THEN 1 ELSE 0
    END) AS new_counterparties,

    CASE
        WHEN a.opened_at > '2026-08-25'
        THEN NULL
        ELSE ROUND(
            SUM(CASE
                WHEN r.counterparty_id IS NOT NULL
                 AND p.counterparty_id IS NULL
                THEN 1 ELSE 0
            END) /
            NULLIF(COUNT(r.counterparty_id), 0),
            4
        )
    END AS new_counterparty_share_7d

FROM accounts a

LEFT JOIN recent r
    ON a.account_id = r.account_id

LEFT JOIN previous p
    ON r.account_id = p.account_id
    AND r.counterparty_id = p.counterparty_id

WHERE a.opened_at < '2026-10-01'

GROUP BY a.account_id, a.opened_at

ORDER BY a.account_id;

-- Compare each account's recent counterparties
-- with those seen during the previous 30 days.
-- Count the relationships that weren't seen earlier.
-- Keep accounts without recent transactions as well.
-- Don't assign a complete-history share to new accounts.



SELECT
    counterparty_id,

    COUNT(*) AS txn_count_30d,

    SUM(amount_usd) AS counterparty_amount_30d

FROM transactions

WHERE account_id = 'A00662'
  AND counterparty_id IS NOT NULL
  AND occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY counterparty_id

ORDER BY counterparty_amount_30d DESC

LIMIT 5;

-- Find the five counterparties involved in the
-- largest transaction amounts for A00662.
-- This helps us see whether most of the money
-- is moving through a few relationships.



SELECT
    account_id,

    SUM(amount_usd) AS non_cash_amount_30d

FROM transactions

WHERE account_id = 'A00662'
  AND counterparty_id IS NOT NULL
  AND occurred_at >= '2026-09-01'
  AND occurred_at < '2026-10-01'
  AND posted_at < '2026-10-01'

GROUP BY account_id;

-- Calculate the total September transaction amount
-- involving known counterparties.
-- Exclude cash transactions because their
-- counterparty IDs are not available.



SELECT
    6540.35 AS top_counterparty_amount,

    86485.05 AS total_non_cash_amount,

    ROUND(
        6540.35 / 86485.05,
        4
    ) AS top_counterparty_concentration_30d;

-- Compare the largest counterparty's transaction
-- amount with the total non-cash transaction amount.
-- This shows how much of the account's activity
-- is concentrated with one counterparty.



WITH counterparty_amounts AS (

    SELECT
        counterparty_id,
        SUM(amount_usd) AS total_amount

    FROM transactions

    WHERE account_id = 'A00662'
      AND counterparty_id IS NOT NULL
      AND occurred_at >= '2026-09-01'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY counterparty_id
)

SELECT
    MAX(total_amount) AS top_counterparty_amount,

    SUM(total_amount) AS total_non_cash_amount,

    ROUND(
        MAX(total_amount) /
        NULLIF(SUM(total_amount), 0),
        4
    ) AS top_counterparty_concentration_30d

FROM counterparty_amounts;

-- First calculate the September amount for each
-- known counterparty.
-- Find the largest amount and compare it with
-- the total across all known counterparties.
-- This shows whether activity is concentrated
-- around a single relationship.



WITH counterparty_amounts AS (

    SELECT
        account_id,
        counterparty_id,
        SUM(amount_usd) AS total_amount

    FROM transactions

    WHERE counterparty_id IS NOT NULL
      AND occurred_at >= '2026-09-01'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY account_id, counterparty_id
),

account_totals AS (

    SELECT
        account_id,
        MAX(total_amount) AS top_counterparty_amount,
        SUM(total_amount) AS total_non_cash_amount

    FROM counterparty_amounts

    GROUP BY account_id
)

SELECT
    a.account_id,

    c.top_counterparty_amount,

    COALESCE(c.total_non_cash_amount, 0)
        AS total_non_cash_amount,

    ROUND(
        c.top_counterparty_amount /
        NULLIF(c.total_non_cash_amount, 0),
        4
    ) AS top_counterparty_concentration_30d

FROM accounts a

LEFT JOIN account_totals c
    ON a.account_id = c.account_id

WHERE a.opened_at < '2026-10-01'

ORDER BY a.account_id;

-- Calculate the amount involving each counterparty.
-- Find the largest counterparty amount for each account.
-- Compare it with the account's total non-cash activity.
-- Keep accounts that have no known counterparties.



WITH counterparty_activity AS (

    SELECT
        counterparty_id,
        COUNT(*) AS txn_count_24h

    FROM transactions

    WHERE account_id = 'A00662'
      AND counterparty_id IS NOT NULL
      AND occurred_at >= '2026-09-30'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY counterparty_id
)

SELECT
    'A00662' AS account_id,

    COALESCE(
        MAX(txn_count_24h), 0
    ) AS repeated_counterparty_max_count_24h

FROM counterparty_activity;

-- Count how many times A00662 transacted
-- with each known counterparty on September 30.
-- Find the highest count among those relationships.
-- Return zero if no known counterparties were involved.



WITH counterparty_activity AS (

    SELECT
        account_id,
        counterparty_id,
        COUNT(*) AS txn_count_24h

    FROM transactions

    WHERE counterparty_id IS NOT NULL
      AND occurred_at >= '2026-09-30'
      AND occurred_at < '2026-10-01'
      AND posted_at < '2026-10-01'

    GROUP BY account_id, counterparty_id
),

account_max AS (

    SELECT
        account_id,
        MAX(txn_count_24h) AS max_txn_count

    FROM counterparty_activity

    GROUP BY account_id
)

SELECT
    a.account_id,

    COALESCE(m.max_txn_count, 0)
        AS repeated_counterparty_max_count_24h

FROM accounts a

LEFT JOIN account_max m
    ON a.account_id = m.account_id

WHERE a.opened_at < '2026-10-01'

ORDER BY repeated_counterparty_max_count_24h DESC,
         a.account_id;

-- Find how often each account transacted with
-- the same counterparty during September 30.
-- Keep accounts with no known counterparty activity.
-- Show the highest transaction counts first.



SELECT
    t.account_id,
    c.home_country,

    COUNT(*) AS non_cash_txn_count_30d,

    SUM(CASE
        WHEN p.registration_country <> c.home_country
        THEN 1
        ELSE 0
    END) AS country_mismatch_count_30d

FROM transactions t

JOIN accounts a
    ON t.account_id = a.account_id

JOIN customers c
    ON a.customer_id = c.customer_id

JOIN counterparties p
    ON t.counterparty_id = p.counterparty_id

WHERE t.account_id = 'A00662'
  AND t.occurred_at >= '2026-09-01'
  AND t.occurred_at < '2026-10-01'
  AND t.posted_at < '2026-10-01'

GROUP BY t.account_id, c.home_country;

-- Check where A00662's counterparties are registered.
-- Compare their countries with the customer's home country.
-- Count how many transactions involve a different country.
-- Cash transactions are excluded because their
-- counterparty information is not available.



SELECT
    t.account_id,
    c.home_country,

    COUNT(*) AS non_cash_txn_count_30d,

    SUM(CASE
        WHEN p.registration_country <> c.home_country
        THEN 1
        ELSE 0
    END) AS country_mismatch_count_30d,

    ROUND(
        SUM(CASE
            WHEN p.registration_country <> c.home_country
            THEN 1
            ELSE 0
        END) / NULLIF(COUNT(*), 0),
        4
    ) AS country_mismatch_share_30d

FROM transactions t

JOIN accounts a
    ON t.account_id = a.account_id

JOIN customers c
    ON a.customer_id = c.customer_id

JOIN counterparties p
    ON t.counterparty_id = p.counterparty_id

WHERE t.account_id = 'A00662'
  AND t.occurred_at >= '2026-09-01'
  AND t.occurred_at < '2026-10-01'
  AND t.posted_at < '2026-10-01'

GROUP BY t.account_id, c.home_country;

-- Compare the customer's home country with the countries
-- where their counterparties are registered.
-- Divide the mismatched transactions by all transactions
-- involving known counterparties.
-- This helps us measure geographic relationship differences.



SELECT
    a.account_id,
    c.home_country,

    COUNT(p.counterparty_id)
        AS non_cash_txn_count_30d,

    SUM(CASE
        WHEN p.registration_country <> c.home_country
        THEN 1 ELSE 0
    END) AS country_mismatch_count_30d,

    ROUND(
        SUM(CASE
            WHEN p.registration_country <> c.home_country
            THEN 1 ELSE 0
        END) /
        NULLIF(COUNT(p.counterparty_id), 0),
        4
    ) AS country_mismatch_share_30d

FROM accounts a

JOIN customers c
    ON a.customer_id = c.customer_id

LEFT JOIN transactions t
    ON a.account_id = t.account_id
    AND t.occurred_at >= '2026-09-01'
    AND t.occurred_at < '2026-10-01'
    AND t.posted_at < '2026-10-01'

LEFT JOIN counterparties p
    ON t.counterparty_id = p.counterparty_id

WHERE a.opened_at < '2026-10-01'

GROUP BY a.account_id, c.home_country

ORDER BY a.account_id;

-- Compare counterparty registration countries with
-- each customer's home country for every account.
-- Keep accounts without recent counterparty activity.
-- Return NULL for the share when there are no
-- known-counterparty transactions to compare.



SELECT
    c.home_country,
    p.registration_country AS counterparty_country,

    COUNT(*) AS txn_count_30d,

    ROUND(SUM(t.amount_usd), 2) AS total_amount_usd

FROM transactions t

JOIN accounts a
    ON t.account_id = a.account_id

JOIN customers c
    ON a.customer_id = c.customer_id

JOIN counterparties p
    ON t.counterparty_id = p.counterparty_id

WHERE t.account_id = 'A00069'
  AND t.occurred_at >= '2026-09-01'
  AND t.occurred_at < '2026-10-01'
  AND t.posted_at < '2026-10-01'

GROUP BY
    c.home_country,
    p.registration_country

ORDER BY txn_count_30d DESC;

-- Check which countries A00069's counterparties
-- are registered in and how much money is involved.
-- This helps us understand the 100% mismatch result
-- before treating it as a possible risk indicator.



SELECT
    COUNT(*) AS known_counterparty_txns_30d,

    SUM(CASE
        WHEN c.home_country IS NULL
          OR TRIM(c.home_country) = ''
        THEN 1 ELSE 0
    END) AS missing_home_country,

    SUM(CASE
        WHEN p.counterparty_id IS NULL
        THEN 1 ELSE 0
    END) AS missing_counterparty_record,

    SUM(CASE
        WHEN p.registration_country IS NULL
          OR TRIM(p.registration_country) = ''
        THEN 1 ELSE 0
    END) AS missing_counterparty_country

FROM transactions t

JOIN accounts a
    ON t.account_id = a.account_id

JOIN customers c
    ON a.customer_id = c.customer_id

LEFT JOIN counterparties p
    ON t.counterparty_id = p.counterparty_id

WHERE t.counterparty_id IS NOT NULL
  AND t.occurred_at >= '2026-09-01'
  AND t.occurred_at < '2026-10-01'
  AND t.posted_at < '2026-10-01';

-- Check whether any September transactions have
-- missing customer or counterparty country details.
-- Also check for counterparty IDs without a matching
-- record in our counterparty table.
-- Missing values could distort our mismatch feature.
