-- AML Behavioural Risk Feature Engineering & Detection Intelligence System
-- SQL exploratory data analysis
-- We're starting with the big picture before investigating individual accounts.
-- These queries only read data. They won't change any table or transaction.

USE aml_behavioural_risk_fe;


-- 1. How does overall transaction activity change from month to month?
-- We count payments, add up their amounts, and check how many accounts were active.
SELECT
    DATE_FORMAT(occurred_at, '%Y-%m') AS transaction_month,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT account_id) AS active_accounts,
    ROUND(SUM(amount_usd), 2) AS total_amount_usd,
    ROUND(AVG(amount_usd), 2) AS avg_transaction_usd
FROM transactions
GROUP BY DATE_FORMAT(occurred_at, '%Y-%m')
ORDER BY transaction_month;

-- Looking at one month by itself can be misleading. This gives us a starting
-- point for spotting changes in overall volume and transaction size.
-- We use the date the transaction occurred, not the date it was posted.
-- A busy month isn't automatically suspicious; later we'll compare customers
-- against their own normal activity instead of relying on bank-wide averages.


-- 2. How much money comes in versus goes out across the full reporting period?
-- This separates credits and debits, but doesn't treat either one as a risk signal.
SELECT
    direction,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT account_id) AS active_accounts,
    ROUND(SUM(amount_usd), 2) AS total_amount_usd,
    ROUND(AVG(amount_usd), 2) AS avg_transaction_usd
FROM transactions
GROUP BY direction
ORDER BY FIELD(direction, 'IN', 'OUT');

-- Incoming and outgoing totals help us understand the dataset's money flows.
-- They aren't account balances, and adding transaction amounts isn't the same
-- as measuring unique money moving through the bank.
-- When we investigate rapid movement of funds later, we'll look at the timing
-- of incoming and outgoing payments for each account, not these totals alone.


-- 3. Are individual and business customers behaving differently?
-- We join through account_id and customer_id, rather than matching names.
SELECT
    c.customer_type,
    COUNT(DISTINCT c.customer_id) AS active_customers,
    COUNT(DISTINCT a.account_id) AS active_accounts,
    COUNT(t.transaction_id) AS total_transactions,
    ROUND(SUM(t.amount_usd), 2) AS total_amount_usd,
    ROUND(AVG(t.amount_usd), 2) AS avg_transaction_usd
FROM transactions t
JOIN accounts a
    ON t.account_id = a.account_id
JOIN customers c
    ON a.customer_id = c.customer_id
GROUP BY c.customer_type
ORDER BY c.customer_type;

-- Business and individual customers often have very different payment sizes.
-- We need this context before setting thresholds for unusual activity.
-- These are transaction-weighted averages, not the average per customer.
-- The inner joins cover customers with transactions. Customers with no activity
-- would need a LEFT JOIN when we're analysing the full customer population.
