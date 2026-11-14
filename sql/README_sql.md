# SQL files — AML Behavioural Risk

This project uses **MySQL 8.0+** and a fixed analysis cutoff of **October 1, 2026**.
The four source tables are `customers`, `accounts`, `counterparties`, and `transactions`.
Load those tables before running the SQL.

## Suggested order

| Step | File | Purpose |
| --- | --- | --- |
| 1 | `data_profiling.sql` | Check missing values and the cash counterparty rule |
| 2 | `data_consistency.sql` | Review dates, amounts, channels and expected activity |
| 3 | `eda.sql` | Explore volume, payment direction and customer types |
| 4 | `feature_readiness.sql` | Check whether the data supports the planned features |
| 5 | `transaction_outlier_analysis.sql` | Explore unusually busy account-days |
| 6 | `activity_features.sql` | Build activity and payment-flow queries step by step |
| 7 | `behaviour_features.sql` | Examine velocity, cash, flow and dormancy |
| 8 | `counterparty_features.sql` | Examine new, repeated and concentrated relationships |
| 9 | `customer_features.sql` | Compare customer activity with KYC expectations |
| 10 | `customer_behaviour.sql` | Explore expectations over the nine-month period |
| 11 | `feature_snapshot.sql` | Build and check the final physical feature table |

Steps 1–10 are **read-only learning/analysis scripts**. Their queries can be run individually.
Only `feature_snapshot.sql` creates and updates tables. Running it again **replaces**
`feature_snapshot_20261001` and its `fe_*_work` tables. It does not modify the four source tables.

## Expected snapshot checks

The last script includes its own validation queries. Key expected results:

| Check | Expected result |
| --- | ---: |
| Snapshot account rows | 2,135 |
| Distinct customers | 1,700 |
| September transaction count | 18,846 |
| September gross transaction amount (USD) | 27,315,157.30 |
| Accounts without September transactions | 25 |
| Accounts without September known counterparties | 32 |
| Undefined new-counterparty shares | 456 |
| Original dictionary features present | 30 |

For account `A00662`, the expected September count is **85** and gross value is
**$91,225.53**. Customer `C00542` has **93** September transactions across
its accounts. These figures were independently checked against the exported CSVs.

## How the figures should be interpreted

- Counts and amounts use the **transaction occurrence date** and a posting cutoff.
- Gross activity includes incoming **and** outgoing amounts. It is not a bank balance.
- In this synthetic dataset, cash transactions have no counterparty ID.
- A NULL ratio can mean no activity or no usable baseline. It does not mean zero risk.
- These are behavioural indicators for investigation, **not confirmed AML cases**.

The source-data CSVs and final Python notebook are maintained outside this SQL folder.
The repository README should explain the initial table creation and CSV import steps.
