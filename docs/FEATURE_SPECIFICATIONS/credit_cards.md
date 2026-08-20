# Credit Cards

Do not persist competing `currentBalance` and `outstandingAmount`. Outstanding and available credit are derived.

`availableCredit = creditLimit − outstandingAmount`

## Purchase
Expense on the card. Increases outstanding, decreases available credit, decreases Net Worth by the new liability.

## Repayment warning
Same currency bank balances only. Exclude Cash, Cards, Goals.

Warn (never block) if bank funds < current outstanding + new purchase.

## Partial payment
Allowed anytime: Bank → Card Transfer. Reduces current outstanding.

## Statement
On bill-generation day, snapshot current outstanding for that cycle. Idempotent on `(profileId, accountId, statementCycle)`. Missed cycles generate when the app next runs. Later purchases belong to the next cycle. V1 does not copy bank due-date/interest logic.

## Settlement
Guided full repayment of the applicable statement: Settle → amount → bank → validate → Transfer `Settled Credit Card Bill` → outstanding reduced → credit restored. Not income or expense. Net Worth unchanged by the settlement itself.

## Required tests
Outstanding reconstruction; partial payment; settlement; credit restoration; statement idempotency; repayment warning; NAB exclusion; Net Worth liability; reconciliation after restart/import/edit/delete.
