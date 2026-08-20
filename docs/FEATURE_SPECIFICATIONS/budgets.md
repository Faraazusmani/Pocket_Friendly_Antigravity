# Budgets

One budget system: category budgets. **No unallocated budget pool.**

```text
TotalMonthlyBudget = SUM(category budgets for month + currency)
AvailableBudget = TotalMonthlyBudget − EligibleSpentToDate
```

A budget attaches to one categoryId. Parent totals are aggregations without double-counting.

Overspending is always allowed and always only warned. Available Budget may be negative.

## Carry-forward
Unused per category = `MAX(0, budget − eligible spend)`. Overspent categories contribute 0.

Ask whether to carry forward. If yes, user allocates the **entire** amount to one or more categories in the new month. Store base vs carry-forward separately. Not a transaction.

## Safe-to-Spend
See ADR-031. Complete only after recurring remaining-scheduled projection exists.

Currency-scoped. Floor at zero.
