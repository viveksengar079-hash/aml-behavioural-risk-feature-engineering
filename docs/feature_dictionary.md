# Feature Dictionary

**Project:** AML Behavioural Risk Feature Engineering & Detection Intelligence System  
**Data:** Synthetic customer, account, counterparty and transaction records  
**Reporting cutoff:** 1 October 2026, 00:00:00  
**Status:** 30 named features are included in `sql/feature_snapshot.sql` and the account snapshot has been validated against key source totals.

## How the features work

- The main table has **one row per account**. Each account also has a `customer_id`.
- The final snapshot is `feature_snapshot_20261001`. This is a **fixed historical snapshot**, not live scoring.
- Transaction windows use `occurred_at`, and the SQL only includes transactions with `posted_at` before the cutoff.
- All amounts are in USD. Gross activity adds incoming and outgoing payments; it is not profit or account balance.
- Cash transactions have no counterparty ID in this synthetic data. They still count toward transaction and cash figures.
- Some ratios are `NULL` when there is no denominator, usable history or comparable data. A missing ratio does not mean low risk.
- Customer expected activity is compared with **all of the customer's accounts combined**, not a single account. The resulting customer-level ratios are copied onto account rows for reference and must not be summed again.
- Features describe behaviour. They are not confirmed money-laundering cases or validated detection labels.

## The 30 feature columns

| # | Feature | Calculation / meaning | Window | Main source |
|---|---|---|---|---|
| 1 | `txn_count_24h` | Number of transactions | 24h | transactions |
| 2 | `txn_count_7d` | Number of transactions | 7d | transactions |
| 3 | `txn_count_30d` | Number of transactions | 30d | transactions |
| 4 | `active_days_30d` | Distinct calendar days with at least one transaction | 30d | transactions |
| 5 | `avg_txn_per_active_day_30d` | `txn_count_30d / active_days_30d` (NULL if 0 active days) | 30d | transactions |
| 6 | `txn_velocity_ratio_24h_vs_prior30d` | `txn_count_24h / (prior_30d_count / 30)`; NULL if prior baseline is zero | 24h vs prior 30d | transactions |
| 7 | `days_since_previous_txn` | Whole days since the latest known transaction before the snapshot; NULL if none | Lifetime as of snapshot | transactions |
| 8 | `amount_total_24h` | Gross amount: sum of all transactions, regardless of IN/OUT | 24h | transactions |
| 9 | `amount_total_7d` | Gross amount | 7d | transactions |
| 10 | `amount_total_30d` | Gross amount | 30d | transactions |
| 11 | `avg_amount_30d` | Mean of `amount_usd`; NULL if no transactions | 30d | transactions |
| 12 | `max_amount_30d` | Largest single transaction; NULL if no transactions | 30d | transactions |
| 13 | `amount_spike_ratio_24h_vs_prior30d` | Gross amount in last 24h divided by `(prior 30-day gross / 30)`; NULL for zero baseline | 24h vs prior 30d | transactions |
| 14 | `round_amount_count_30d` | Count of transactions whose amount is an exact multiple of $1,000; exploratory heuristic only | 30d | transactions |
| 15 | `cash_amount_share_30d` | Cash gross amount / total gross; NULL when total gross is zero | 30d | transactions |
| 16 | `inflow_amount_24h` | Sum `amount_usd` where `direction='IN'` | 24h | transactions |
| 17 | `outflow_amount_24h` | Sum `amount_usd` where `direction='OUT'` | 24h | transactions |
| 18 | `inflow_amount_30d` | Incoming total | 30d | transactions |
| 19 | `outflow_amount_30d` | Outgoing total | 30d | transactions |
| 20 | `outflow_inflow_ratio_30d` | Outflow / inflow; NULL when inflow zero | 30d | transactions |
| 21 | `net_flow_30d` | Inflow minus outflow (a payments net-flow proxy, not verified balance) | 30d | transactions |
| 22 | `unique_counterparties_7d` | Distinct non-NULL counterparties | 7d | transactions |
| 23 | `unique_counterparties_30d` | Distinct non-NULL counterparties | 30d | transactions |
| 24 | `new_counterparty_share_7d` | Share of unique counterparties in last 7d not seen in prior 30d; NULL if none in recent window | 7d vs preceding 30d | transactions |
| 25 | `top_counterparty_concentration_30d` | Largest non-cash counterparty gross amount / total non-cash gross amount; NULL if no non-cash activity | 30d | transactions |
| 26 | `repeated_counterparty_max_count_24h` | Highest 24h transaction count for any one non-NULL counterparty | 24h | transactions |
| 27 | `expected_count_ratio_30d` | Total 30d transactions across the customer's accounts / expected monthly customer count; NULL if expected count is zero | 30d | customers, accounts, transactions |
| 28 | `inflow_vs_expected_turnover_ratio_30d` | Total 30d inflow across the customer's accounts / expected monthly customer turnover; a proxy, not a direct like-for-like measure | 30d | customers, accounts, transactions |
| 29 | `country_mismatch_share_30d` | Share of known-counterparty transactions with registration country different from customer home country; NULL when country data is incomplete; not proof of cross-border movement | 30d | all 4 tables |
| 30 | `dormant_reactivation_flag_24h` | 1 when the first transaction in the latest 24h follows the previous known transaction by 60+ full days; NULL if earlier history cannot be established | Last 24h + prior history | transactions, accounts |

## Other columns in the snapshot

The table also has identifiers and context such as `account_id`, `customer_id`, `customer_type`, `home_country`, `account_opened_at`, `snapshot_date`, `expected_monthly_txn_count`, and `expected_monthly_turnover_usd`.

`eligible_30d_history` and `eligible_prior30d_history` indicate whether the account has enough age for the relevant monthly and earlier baseline comparisons. Additional columns, including `actual_customer_txn_count_30d`, `actual_customer_turnover_30d`, `cash_amount_30d`, `txn_velocity_ratio`, and `amount_spike_ratio`, support investigation and the Python notebook. These supporting columns are not counted as extra dictionary features.

## Important interpretation notes

- **Velocity and amount spikes:** September 30 is compared with the 30 days before it, not an overlapping period.
- **New counterparties:** September 24–30 is compared with August 25–September 23.
- **Country mismatch:** The comparison uses customer home country and counterparty registration country. It is **not** a confirmed international transfer.
- **Expected turnover:** The SQL keeps both an inflow-based ratio and a separate gross-turnover ratio. They answer different questions, and both depend on the meaning of the customer's stated expectation.
- **Dormancy:** No recent activity gives a reactivation flag of 0. If recent activity exists but there is no reliable earlier transaction or the account is too new, the flag can be `NULL`.
- **History checks:** The snapshot explicitly stores 30-day and prior-30-day eligibility flags. It does not contain a separate eligibility flag for every lookback window originally proposed.

The working SQL and detailed window rules are in `sql/feature_snapshot.sql` and `docs/window_rules.md`.
