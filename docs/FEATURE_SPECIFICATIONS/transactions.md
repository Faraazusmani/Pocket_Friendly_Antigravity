# Transactions

## Types
Primary: Expense, Income, Transfer.

Balance Adjustment is a distinct event from Account management, not a primary `+` type.

Opening balances, credit-card limits and budget allocations are not transactions.

## Money
Integer minor units. Positive allocation amounts only. Direction via SOURCE / DESTINATION.

## Record Sheet
Type, amount, category, account/endpoints, date, payment mode, notes, tag, recurring.

Income requires a category. A transaction cannot be saved without a payment mode.

No mutation is committed until Save.

## Expense / Income splits
“Does this expense contain multiple categories?”
“Did you pay from two different accounts for this transaction?”

Both may be active. Each allocation family sums to the transaction total.

## Transfers
Endpoints: Account or Goal. Not income or expense. No category splits.

Patterns: Account→Account, Account→Goal, Goal→Account, Goal→Goal (domain; UI optional).

Default payment mode: Bank Transfer (account/card); Internal Transfer (Goal transfers).

List display: `HDFC ↔ Emergency Fund    ₹2,000`

Split transfers: multiple sources and/or destinations; sum(sources) = sum(destinations). Initial UI may simplify many-to-many.

## Goal transfers
See `goals.md`. Ordinary expenses must not carry a Goal relationship.

## Credit-card payments
Bank → Card is a Transfer. Settlement may use subtype/label `Settled Credit Card Bill`.

## Editing / deletion
Recalculate derived state. Goal withdrawal still cannot exceed Goal balance.

## Search
Notes, tags, amount. Contains match vs inclusive `min-max` range. Currency-scoped. Integer comparison.

## Required tests
See DECISIONS ADR-023–027 and IMPLEMENTATION_ORDER Phases 2–2b, 4–5, 9.
