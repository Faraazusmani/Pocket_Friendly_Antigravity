# Pocket Friendly — Business Rules Specification

## 1. Fundamental Rule
Pocket Friendly records and explains financial activity. It does not restrict legitimate spending, overspending, or credit-card purchases.

**Exception:** a Goal balance must never become negative. Goal withdrawals that exceed the current Goal balance are rejected.

## 2. Transaction Types
Primary user-facing types:
- Expense
- Income
- Transfer

Balance Adjustment is a distinct internal event, not offered as a primary `+` type.

Opening balances, credit-card limits, and budget allocations (including carry-forward) are **not** transactions.

## 3. Expense
- Reduces relevant account balance (or increases card outstanding)
- Increases category spending
- Counts toward budget when the category is budgeted (eligible spend)
- Affects savings
- Affects insights
- Ordinary expenses have **no** Goal relationship

## 4. Income
- Increases account balance
- Requires a category
- Counts as income
- Does not count as expense
- Affects savings

## 5. Transfer
- Decreases source endpoint
- Increases destination endpoint
- Not income
- Not expense
- Does not consume spending budget
- Endpoints are Account or Goal
- Account → Account does not change Net Worth
- Account → Goal / Goal → Account move owned money between ordinary accounts and Goal balances; Net Worth is preserved when Goal balances are included (ADR-032)
- Bank → Credit Card reduces an asset and a liability; Net Worth unchanged by the transfer itself

## 6. Split Categories
Expense/Income may split categories. Allocation amounts are positive. Sum equals transaction total.

Transfers do not category-split.

## 7. Split Funding / Transfer Allocations
Multiple source and/or destination endpoints may be used. Amounts are always positive. Role is SOURCE or DESTINATION. Sum(sources) = Sum(destinations).

## 8. Simultaneous Splits
Expense may split categories and funding accounts together. Each family of allocations must sum to the transaction total.

## 9. Opening Balance
An initial Bank/Cash balance is an opening balance, not income.

An initial credit-card outstanding at account creation is opening outstanding, not an expense.

## 10. Balance Adjustment
Traceable event from Account → More → Adjust Balance.

Affects reconstructed account/card balance and Net Worth.

Must **not** affect income, expenses, category spending, budgets, savings, goal savings, trends, or Safe-to-Spend.

Goals cannot be balance-adjusted.

## 11. Account Deletion
Archive, remove from active selection, preserve history, warn the user. Archived accounts cannot receive new transactions.

## 12. Category Deletion
Parent deletion archives children from active use while preserving history. Child deletion does not affect parent. Goal categories follow Goal archive rules.

## 13. Category Rename
Renaming updates displayed names in historical records.

## 14. Tags
Zero or one tag per transaction. Tags are global within a profile.

## 15. Payment Modes
Every transaction requires a payment mode.

Compatibility:
- Credit Card accounts: credit-card-compatible modes
- Cash accounts: Cash-compatible modes
- Bank accounts: bank-compatible modes

Defaults:
- Account → Account and card settlement: Bank Transfer (changeable to a compatible mode)
- Goal transfers: Internal Transfer

Incompatible modes must not be selectable.

## 16. Net Available Balance and Net Worth
Currency-scoped. Never silently convert.

```text
NetAvailableBalance = Bank balances + Cash balances
NetWorth = Bank balances + Cash balances + Goal balances − Credit Card outstanding
```

Credit-card limits are not assets. Goals are excluded from Net Available Balance so they are not treated as extra liquid cash.

## 17. Credit-Card Purchase
Expense on the card:
- Increases category spending
- Increases outstanding
- Decreases available credit
- Decreases Net Worth by the new liability

## 18. Credit-Card Repayment Warning
Currency-scoped.

```text
EligibleRepaymentFunds = SUM(Bank balances in the same currency)
```

Exclude Cash, Cards, Goals, other currencies.

Warn (do not block) if:

```text
EligibleRepaymentFunds < currentOutstanding + newPurchaseAmount
```

## 19. Credit-Card Statement
On bill-generation day, snapshot current outstanding for that cycle (idempotent). Notify if enabled. Later purchases belong to the next cycle. Missed cycles generate when the app next runs.

## 20. Credit-Card Settlement
Guided UX against the applicable statement balance:
1. Show amount
2. Settle
3. Select bank account
4. Validate
5. Create Transfer (`Settled Credit Card Bill`)
6. Reduce outstanding
7. Restore available credit

Not income. Not expense. Warn if the selected bank cannot cover; do not silently partial-settle the guided full-pay flow.

## 21. Partial Credit-Card Payments
Allowed at any time as Bank → Card Transfer. Reduce current outstanding by the payment amount.

## 22. Budget
Each budget attaches to one categoryId for a month/year/currency.

```text
TotalMonthlyBudget = SUM(category budgets)
AvailableBudget = TotalMonthlyBudget − EligibleSpentToDate
```

Available Budget may be negative. Spending is never blocked.

Parent category figures are aggregations. Spending assigned to a child is not counted twice.

## 23. Unallocated Pool
Removed. Do not implement.

## 24. Overspending
Warn only. Never block (except Goal negative-balance rule).

## 25. Carry-Forward
At month start, unused = sum of `MAX(0, categoryBudget − eligibleSpend)`.

Ask whether to carry forward. If yes, user must allocate the entire amount to one or more categories in the new month. Store carry-forward separately from base budget. Not a transaction.

## 26. Safe-to-Spend
See ADR-031. Currency-scoped. Floor at zero.

## 27. Goals
Manually managed objectives (savings, EMI, SIP, and others). Linked category under `Goals`.

Balance/progress is reconstructed from Goal transfers only.

## 28. Goal Contribution
Account → Goal Transfer.
- Source account decreases
- Goal increases
- Category: `Goals → <Goal>`
- Not expense, not budget spend
- Increases Goal savings

## 29. Goal Savings Reporting
For a period, insights must distinguish:

1. Total income
2. Total actual spending
3. Goal savings = net transfers into Goals
4. Account savings = change in ordinary account money after income, expenses and transfers, excluding money already represented as Goal savings
5. Total savings

## 30. Goal Withdrawal
Goal → Account Transfer.
- Goal decreases
- Destination account increases
- Not income
- Decreases Goal savings
- **Reject** if amount > current Goal balance. No partial commit. No negative Goal.

## 31. Goal Date
No date → one-year projection. If target date passes, ask for a new date.

## 32. EMI/SIP
Distinct Goal types. May use recurring contribution/reminder behaviour.

## 33. Recurring Transactions
Reminder or Automatic Recording. User-selected frequency.

## 34. Recurring Date
If the scheduled day does not exist in a month, use that month’s last day.

## 35. Automatic Recording Failure
If the occurrence cannot be recorded safely, mark FAILED, do not create a transaction, notify the user. Retry uses the same occurrence identity.

## 36. Recurring Edit
Ask whether all future occurrences should use the new configuration. If yes: deactivate old rule at split; new rule from next occurrence; historical recorded transactions unchanged.

## 37. Recurring Idempotency
`(recurringTransactionId, scheduledOccurrenceDate)` is unique. Duplicate OS/notification/retry must not duplicate transactions. Missed occurrences are evaluated independently.

## 38. Transaction Editing
Editing any applicable field recalculates dependent derived state. Goal-withdrawal validation still applies.

## 39. Transaction Deletion
Deletion reverses effects across accounts, Goals, cards, budgets and insights. History of the event is preserved per archive/delete rules for the transaction record.

## 40. Dashboard Month
Changing Dashboard month changes only the Snapshot. Goals, recent transactions and other current Dashboard content remain current.

## 41. Insights Period
Month/year filters. Definitions must match the rest of the app.

## 42. Natural-Language Queries
Local questions about transactions, categories, accounts, budgets, goals, spending, income, savings, trends, dates, tags and payment modes.

## 43. Natural-Language Actions
Prefill only. Never commit. Income examples must include a category.

## 44. Search
Notes, tags, amount. Amount uses integer minor units.

- `500` contains-match on the user-facing numeric representation (`500`, `1500`, `2500`, `5000`)
- `500-1000` inclusive range
- Currency-scoped
- Do not search formatted display strings as financial truth

## 45. Multi-Currency
Historical records retain original currency. Default-currency change affects future records only. Dashboard shows per-currency sections.

## 46. Budget Currency
Do not combine unrelated currencies.

## 47. Profile Isolation
No financial record may cross profiles.

## 48. Import Merge
See ADR-035. Never silently destroy financial information. Recalculate derived state after merge.

## 49. User Control
No financial mutation may happen silently. Automated features follow their explicit rules (including recurring idempotency).

## 50. Feedback
Meaningful mutations should produce immediate visual feedback and appropriate subtle haptics where possible.

## 51. Atomicity
Transfers, splits, Goal moves, card settlement, balance adjustments, budget carry-forward, import/merge and recurring record+occurrence writes are atomic. Failure rolls back completely.
