# Calculation Windows and Missing-Data Rules

**Project:** AML Behavioural Risk Feature Engineering & Detection Intelligence System  
**Final snapshot:** `feature_snapshot_20261001`  
**Cutoff:** 1 October 2026, 00:00:00  
**Status:** Rules below describe the **implemented SQL snapshot**, not proposed work.

## Which transactions are included?

The SQL starts from `accounts`, then calculates activity from `transactions`. To count toward a feature, a transaction must fall inside the feature's occurrence-time window **and** have `posted_at < '2026-10-01'`. Nothing after the cutoff is included.

The start of each window is included and the end is excluded. This keeps one transaction from falling into two adjacent periods.

## Exact windows used

| Measure | Start | End (excluded) |
|---|---|---|
| Last 24 hours | Sep 30, 2026 00:00 | Oct 1, 2026 00:00 |
| Last 7 days | Sep 24, 2026 00:00 | Oct 1, 2026 00:00 |
| Last 30 days | Sep 1, 2026 00:00 | Oct 1, 2026 00:00 |
| Prior 30 days for spike ratios | Aug 31, 2026 00:00 | Sep 30, 2026 00:00 |
| Previous 30 days for new counterparties | Aug 25, 2026 00:00 | Sep 24, 2026 00:00 |
| Recent counterparties | Sep 24, 2026 00:00 | Oct 1, 2026 00:00 |

The prior 30-day spike period does **not** include September 30. The earlier counterparty period does **not** include the latest seven days.

## Rules for missing values

- Counts and sums can be zero when an account has no qualifying transactions.
- The average payment amount and maximum payment amount are `NULL` when there are no payments in the 30-day window.
- Cash share is `NULL` when total monthly gross amount is zero. This affected **25 accounts**.
- New-counterparty share is `NULL` when there are no known counterparties in the recent seven days (or the account lacks the required prior history). The completed output has **456 NULL values**, all on accounts with zero recent known counterparties.
- The spike and velocity ratios need a nonzero preceding baseline and enough account age. The snapshot uses `eligible_prior30d_history` for this.
- `eligible_30d_history` records whether the account was open by September 1. Some observed features are still populated for younger accounts; don't call those a full-month history.
- Customer expected-activity ratios use totals across all accounts for the same customer. The SQL does not add a separate 30-day history eligibility condition to those ratios, so interpret new customers carefully.
- A missing ratio is not automatically zero and is not a risk category.

## Cash, counterparties and country comparisons

In these synthetic source files, cash transactions have a blank `counterparty_id`. They still count toward transaction totals and cash share. They are excluded from calculations requiring a named counterparty.

`country_mismatch_share_30d` compares the customer's home country with a counterparty's **registration country**. If country details are missing for relevant transactions, the SQL leaves the ratio `NULL`. This is a profile comparison, not evidence that money crossed a border.

## Dormancy check

The SQL looks at the first known transaction on September 30 and the last known transaction before that day.

- It marks **1** if the gap is at least 60 full days and there is enough account history.
- It marks **0** when there was no activity on September 30, or when a known earlier transaction shows a shorter gap.
- It leaves **NULL** when recent activity exists but the earlier history cannot be established or the account is too new.

This flag only points to a possible reactivation. A genuine alert still needs an analyst to investigate the context.

## Key checks completed

- 2,135 accounts in the snapshot, with no duplicate account IDs.
- 18,846 September transactions and $27,315,157.30 gross amount, matching the source data.
- 25 accounts with no September transactions.
- 32 accounts with no known September counterparties.
- 456 undefined new-counterparty shares, explained by no recent known-counterparty activity.

The exact SQL logic and further checks are in `sql/feature_snapshot.sql`. For a new MySQL setup, import the source data before running this script.
