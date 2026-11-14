# Feature Build Plan — Completed Work

**Project:** AML Behavioural Risk Feature Engineering & Detection Intelligence System  
**Initial design:** 30 behavioural features in three priority groups  
**Final result:** A fixed account snapshot for 1 October 2026, followed by Python rule-based alert analysis and Tableau dashboards.

## What I wanted to build

I started with simple account activity, payment amounts, and money coming in or going out. I then added counterparty behaviour, customer expectations and some features that need extra care when interpreting them.

These are the **original priority groups**. They show how I planned the work; they are no longer pending tasks.

## Priority A — Original first group (17 features)

| # | Feature | Why it comes first |
|---|---|---|
| 1 | `txn_count_24h` | Identifies concentrated activity in one day |
| 3 | `txn_count_30d` | Gives a monthly volume reference |
| 6 | `txn_velocity_ratio_24h_vs_prior30d` | Spots a jump against earlier behaviour; needs a valid prior baseline |
| 7 | `days_since_previous_txn` | Helps identify accounts returning after a long gap |
| 8 | `amount_total_24h` | Measures sudden large gross payment movement |
| 10 | `amount_total_30d` | Establishes monthly gross movement |
| 13 | `amount_spike_ratio_24h_vs_prior30d` | Compares today's gross movement with an earlier baseline |
| 15 | `cash_amount_share_30d` | Measures cash reliance without inventing cash counterparties |
| 16 | `inflow_amount_24h` | Shows funds arriving in the latest day |
| 17 | `outflow_amount_24h` | Shows funds leaving in the latest day |
| 18 | `inflow_amount_30d` | Captures monthly incoming funds |
| 19 | `outflow_amount_30d` | Captures monthly outgoing funds |
| 20 | `outflow_inflow_ratio_30d` | Helps spot accounts sending most incoming funds onward |
| 21 | `net_flow_30d` | Records inflows minus outflows; not an account balance |
| 23 | `unique_counterparties_30d` | Describes counterparty breadth |
| 27 | `expected_count_ratio_30d` | Compares activity with expectations **only after customer/account granularity is checked** |
| 30 | `dormant_reactivation_flag_24h` | Flags renewed activity after inactivity, subject to adequate history |

## Priority B — Original second group (9 features)

| # | Feature | Main purpose |
|---|---|---|
| 2 | `txn_count_7d` | Seven-day frequency |
| 4 | `active_days_30d` | How many separate days an account was active |
| 5 | `avg_txn_per_active_day_30d` | Frequency on days with activity |
| 9 | `amount_total_7d` | Seven-day gross movement |
| 11 | `avg_amount_30d` | Typical transaction size |
| 12 | `max_amount_30d` | Largest recent payment |
| 22 | `unique_counterparties_7d` | Short-term breadth of counterparties |
| 24 | `new_counterparty_share_7d` | New relationships relative to preceding history |
| 25 | `top_counterparty_concentration_30d` | Dependence on a single counterparty |

## Priority C — Original exploratory group (4 features)

| # | Feature | Why we handle it carefully |
|---|---|---|
| 14 | `round_amount_count_30d` | Multiples of $1,000 are a weak heuristic by themselves |
| 26 | `repeated_counterparty_max_count_24h` | Useful context, but repeated payments may be routine |
| 28 | `inflow_vs_expected_turnover_ratio_30d` | 'Turnover' definition may not match inflows; comparison is a proxy only |
| 29 | `country_mismatch_share_30d` | Registration-country mismatch is not evidence of an international payment |


## What was actually completed

- Created the 30 named feature columns in `feature_snapshot_20261001` using `sql/feature_snapshot.sql`.
- Kept one row per account, including accounts with no September transactions.
- Used September 1–30, 2026 as the main 30-day period, ending at the October 1 cutoff.
- Built customer-level expected-activity totals by adding activity across the customer's accounts.
- Validated 2,135 account rows, 18,846 September transactions and $27,315,157.30 in gross September activity.
- Checked missing ratios and compared key outputs in Python.
- Created five rule-based alert groups, a customer investigation queue and three Tableau dashboards.

## Decisions made during the build

| Issue | What I did |
|---|---|
| One customer can have several accounts | Added account activity at customer level before comparing it with customer expectations |
| Cash has no counterparty ID | Kept cash activity in total and cash measures, but excluded it from known-counterparty calculations |
| Some accounts have limited history | Used history eligibility fields for the monthly and spike calculations; some other measures remain observational |
| A ratio has no usable denominator | Left it as `NULL` rather than reporting a misleading zero |
| New-counterparty and spike windows overlap if used carelessly | Used separate comparison periods before the recent activity |
| Synthetic data has no proven financial-crime outcomes | Treated the outputs as candidate alerts, not confirmed suspicious activity |

## What the work does not cover

This project has **one historical scoring cutoff**. It is not a real-time monitoring platform, does not test alert precision or recall, and does not establish true-positive or false-positive rates. The thresholds are demonstration rules for analyst investigation.

For exact column definitions, use `docs/feature_dictionary.md`. For the reporting windows, use `docs/window_rules.md`.
