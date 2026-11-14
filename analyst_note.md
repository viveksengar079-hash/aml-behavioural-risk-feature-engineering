# Analyst Note — Behavioural Risk Review

**Analysis period:** September 2026  
**Snapshot cutoff:** 1 October 2026  
**Data:** Synthetic AML portfolio dataset  
**Tools used:** MySQL, Python and Tableau

## Why I did this analysis

I wanted to see how customer transaction history can help an analyst decide which accounts need attention first. Rather than judging customers only by their original risk rating, I checked what they actually did: how much money moved, whether activity increased suddenly, how cash was used and whether counterparties changed.

The results are **candidate alerts for review**, not evidence that any customer committed a crime.

## What the data showed

The SQL snapshot covers **2,135 accounts** and **18,846 September transactions**, with **$27,315,157.30** in gross payment activity. Gross includes both incoming and outgoing payments. It is not a bank balance or profit.

The five detection rules produced **168 alerts across 157 customers**. Most customers triggered one rule (147 customers). Nine customers triggered two rules and one customer triggered three. Multiple rules can help set review priority, but do not by themselves prove suspicious activity.

| Rule | Alerts | What I would check |
|---|---:|---|
| High Turnover and Expected Activity Deviation | 69 | Whether actual customer activity fits the stated business and expected volume |
| High Cash Amount and Cash Share | 50 | Cash use, customer type and whether the cash pattern is expected |
| Unusual New Counterparty Activity | 22 | Why several unfamiliar parties appeared in a short period |
| High Counterparty Concentration | 16 | Whether repeated payments to one party have a clear business purpose |
| Sudden Transaction Velocity Spike | 11 | Whether a sudden burst of transactions has a reasonable explanation |

## How I would prioritize reviews

I would start with customers who triggered more than one rule, especially if the alert reasons point to different changes in behaviour. I would then consider size of activity, how unusual it is for the customer's peer group, and whether the customer's profile supports it.

The Investigation Workbench allows selecting a customer and viewing the matching alerts. As a test, customer `C00819` has three rule triggers. The dashboard's customer-to-alert filter was checked on this example. This makes it easier to review several signals together rather than treating each alert in isolation.

A basic analyst review would check the customer's profile and stated activity, examine recent transaction details and counterparties, document plausible explanations, and escalate only when concerns remain after review.

## Data-quality points that matter

- **25 accounts** had no September activity. Their cash share is undefined, not zero risk.
- **456 accounts** had no known counterparties in the recent seven days, so their new-counterparty share is undefined.
- Cash records have no counterparty ID in this synthetic dataset. They remain in cash and overall activity measures.
- The alert output has **130 records with no review tier assigned**, 33 marked `Initial review` and 5 marked `Enhanced review`. Unassigned does **not** mean low risk.
- Customer expected-activity comparisons use totals across all accounts owned by that customer, so the customer figures should not be added again across account rows.

## Limitations and next steps

The data is synthetic, the thresholds are demonstration rules, and the results cover one historical snapshot. I did not have verified investigation outcomes or labels identifying true suspicious activity. For that reason, I cannot claim detection accuracy, a false-positive rate or actual fraud prevention benefits.

In a real AML team, the next steps would be to test the thresholds on historical reviewed cases, record analyst outcomes, study the causes of unnecessary alerts and tune the rules with proper approvals. None of that is presented as completed work here.

**Main takeaway:** Transaction features are useful for focusing reviews, but an alert should always be supported by customer context and a documented investigation.
