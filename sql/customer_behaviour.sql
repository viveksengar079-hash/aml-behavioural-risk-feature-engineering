-- AML Behavioural Risk Feature Engineering & Detection Intelligence System
-- Customer behaviour compared with expected activity
-- This file only reads data from aml_behavioural_risk_fe.
-- Reporting period: January 1 to September 30, 2026 (nine full months).

USE aml_behavioural_risk_fe;


-- 1. Are business and individual customers making as many payments as expected?
-- We first count transactions for each customer across all of their accounts.
WITH customer_activity AS (
    SELECT
        c.customer_id,
        c.customer_type,
        c.expected_monthly_txn_count,
        COUNT(t.transaction_id) AS observed_9m_txns
    FROM customers c
    LEFT JOIN accounts a
        ON c.customer_id = a.customer_id
    LEFT JOIN transactions t
        ON a.account_id = t.account_id
       AND t.occurred_at >= '2026-01-01'
       AND t.occurred_at < '2026-10-01'
    GROUP BY
        c.customer_id, c.customer_type, c.expected_monthly_txn_count
)
SELECT
    customer_type,
    COUNT(*) AS customers,
    SUM(expected_monthly_txn_count) AS expected_monthly_txns,
    SUM(observed_9m_txns) AS observed_9m_txns,
    ROUND(SUM(observed_9m_txns) / 9, 2) AS observed_monthly_avg,
    ROUND(
        SUM(observed_9m_txns) / NULLIF(9 * SUM(expected_monthly_txn_count), 0),
        2
    ) AS activity_ratio
FROM customer_activity
GROUP BY customer_type
ORDER BY customer_type;

-- The comparison is based on all nine months, not just a busy week.
-- It tells us whether a customer group is broadly above or below its expected
-- payment count. A group average can hide unusual individual customers,
-- which is why we check customer-level differences next.


-- 2. Which customers have made the most payments relative to their profiles?
-- A ratio of 2.00 means twice the expected number of payments over nine months.
WITH customer_activity AS (
    SELECT
        c.customer_id,
        c.customer_type,
        c.baseline_risk_rating,
        c.expected_monthly_txn_count,
        COUNT(t.transaction_id) AS observed_9m_txns
    FROM customers c
    LEFT JOIN accounts a
        ON c.customer_id = a.customer_id
    LEFT JOIN transactions t
        ON a.account_id = t.account_id
       AND t.occurred_at >= '2026-01-01'
       AND t.occurred_at < '2026-10-01'
    GROUP BY
        c.customer_id, c.customer_type, c.baseline_risk_rating,
        c.expected_monthly_txn_count
)
SELECT
    customer_id,
    customer_type,
    baseline_risk_rating,
    expected_monthly_txn_count,
    observed_9m_txns,
    ROUND(observed_9m_txns / NULLIF(9 * expected_monthly_txn_count, 0), 2)
        AS txn_count_ratio
FROM customer_activity
ORDER BY
    observed_9m_txns / NULLIF(9 * expected_monthly_txn_count, 0) DESC,
    customer_id
LIMIT 8;

-- A high ratio means the customer made more payments than expected, but it
-- doesn't tell us when the increase happened or why. We would check the dates,
-- amounts, counterparties and customer profile before recommending a review.
-- The risk rating is included as context, not as proof of wrongdoing.


-- 3. Which customers have the largest gap between expected monthly turnover
--    and the total value of their recorded transactions?
WITH customer_amounts AS (
    SELECT
        c.customer_id,
        c.customer_type,
        c.expected_monthly_turnover_usd,
        COALESCE(SUM(t.amount_usd), 0) AS observed_gross_9m_usd
    FROM customers c
    LEFT JOIN accounts a
        ON c.customer_id = a.customer_id
    LEFT JOIN transactions t
        ON a.account_id = t.account_id
       AND t.occurred_at >= '2026-01-01'
       AND t.occurred_at < '2026-10-01'
    GROUP BY
        c.customer_id, c.customer_type, c.expected_monthly_turnover_usd
)
SELECT
    customer_id,
    customer_type,
    expected_monthly_turnover_usd,
    ROUND(observed_gross_9m_usd / 9, 2) AS observed_monthly_gross_usd,
    ROUND(
        observed_gross_9m_usd / NULLIF(9 * expected_monthly_turnover_usd, 0),
        2
    ) AS gross_to_expected_ratio
FROM customer_amounts
ORDER BY
    observed_gross_9m_usd / NULLIF(9 * expected_monthly_turnover_usd, 0) DESC,
    customer_id
LIMIT 8;

-- We add incoming and outgoing transaction amounts here as a first-pass measure
-- of payment activity. That is NOT the same as confirmed business turnover:
-- the same money could arrive and leave again. Before turning this comparison
-- into a risk feature, we need to agree on the meaning of 'expected turnover'
-- and whether credits, debits or both should count.


-- 4. Do customers with higher payment counts come from one risk group?
-- We count customers whose nine-month transaction counts exceed their profiles
-- by at least two or three times.
WITH customer_activity AS (
    SELECT
        c.customer_id,
        c.baseline_risk_rating,
        c.expected_monthly_txn_count,
        COUNT(t.transaction_id) AS observed_9m_txns
    FROM customers c
    LEFT JOIN accounts a
        ON c.customer_id = a.customer_id
    LEFT JOIN transactions t
        ON a.account_id = t.account_id
       AND t.occurred_at >= '2026-01-01'
       AND t.occurred_at < '2026-10-01'
    GROUP BY
        c.customer_id, c.baseline_risk_rating, c.expected_monthly_txn_count
)
SELECT
    baseline_risk_rating,
    COUNT(*) AS customers,
    ROUND(
        AVG(observed_9m_txns / NULLIF(9 * expected_monthly_txn_count, 0)),
        2
    ) AS avg_txn_count_ratio,
    SUM(observed_9m_txns >= 18 * expected_monthly_txn_count)
        AS customers_at_least_2x,
    SUM(observed_9m_txns >= 27 * expected_monthly_txn_count)
        AS customers_at_least_3x
FROM customer_activity
GROUP BY baseline_risk_rating
ORDER BY FIELD(baseline_risk_rating, 'LOW', 'MEDIUM', 'HIGH');

-- We shouldn't assume that a LOW-rated customer always behaves normally.
-- These counts show where activity diverges from the customer's own stated
-- expectations, regardless of their starting risk category. Any follow-up
-- would still need a time-based review and a plausible business explanation.
