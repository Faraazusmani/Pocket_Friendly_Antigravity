# Pocket Friendly — Architectural Decisions

## Precedence

Where an earlier PRD section, ADR, roadmap, implementation note, or generated document conflicts with a later decision in this file, **the later decision takes precedence**.

In particular:

- ADR-010 is superseded by ADR-023 (Goal transfers).
- ADR-011 and ADR-012 are superseded by ADR-034 (no unallocated budget pool).
- Goal contributions are Transfers, not Expenses.
- There is no `UnallocatedBudgetPool`.

Do not silently invent behaviour. If a later decision still leaves a rule unimplementable, stop and flag it.

---

## ADR-001 — Local-first
All financial data remains on-device. No cloud financial database.

## ADR-002 — Flutter
Use Flutter for a shared Android/iOS codebase. Android ships first.

## ADR-003 — No recurring backend cost
Core functionality must not depend on paid remote infrastructure.

## ADR-004 — Privacy by architecture
Financial data must not leave the device during normal operation.

## ADR-005 — Natural-language actions require confirmation
The assistant may parse and prefill but never directly commits a financial mutation.

## ADR-006 — Credit-card settlement is a transfer
The original purchase is the expense. Settling the credit card is a transfer from a bank account to the card. Partial bank → card payments are also transfers.

## ADR-007 — Deleted entities are archived
Historical transactions remain valid after account/category/goal/tag/payment-mode deletion.

## ADR-008 — Historical names follow current entity names
Renaming an entity updates its displayed name in historical records. The relationship remains stable.

## ADR-009 — Split transactions use allocations
A user-facing transaction may contain multiple category allocations and/or multiple transfer-endpoint allocations.

## ADR-010 — SUPERSEDED
~~Goal contributions are expenses.~~ See **ADR-023**.

## ADR-011 — SUPERSEDED
~~Total budget includes an unallocated pool.~~ See **ADR-034**.

## ADR-012 — SUPERSEDED
~~Carry-forward becomes an unallocated pool.~~ See **ADR-034**.

## ADR-013 — Multi-currency is historical and non-converting
Historical records retain their original currency. Changing default currency affects future transactions only. No automatic external exchange-rate conversion. Dashboard totals are shown per currency.

## ADR-014 — Dashboard month selector is Snapshot-only
Changing the Dashboard month changes only the Snapshot. Other Dashboard content remains current.

## ADR-015 — Navigation mode switch
Explore transforms the navigation pill in place from Home/Transactions/Explore to Goals/Categories/Insights. It does not expand upward.

## ADR-016 — Separate transaction action
The `+` action is visually separate from the navigation pill and always opens Record Transaction.

## ADR-017 — One app lock
The application uses one app-wide PIN/device-authentication lock rather than separate profile locks.

## ADR-018 — Lossless backup
Pocket Friendly's custom encrypted `.pfbackup` format is the authoritative format for complete restoration. CSV/Excel are human-readable exports and are not lossless.

## ADR-019 — Profiles are independent
Multiple local profiles may manage completely separate financial environments.

## ADR-020 — No external financial recommendations
Insights are restricted to the user's own financial data. No external investment/product recommendations.

## ADR-021 — Voice must remain local
If reliable on-device/offline speech recognition is unavailable, voice is disabled rather than using a remote speech service.

## ADR-022 — Inform, never restrict
Budget, ordinary account-balance and credit-card repayment warnings do not block user decisions.

**Exception (ADR-023):** a Goal balance must never become negative. Goal withdrawals that exceed the current Goal balance are rejected, not merely warned.

---

## ADR-023 — Goals as transfer endpoints (R2, R3, Q1, Q8)

A Goal is **both**:

1. A category under the reserved parent `Goals` (`Goals → <Goal Name>`), used for filtering, search and insights identity.
2. A separate balance-holding domain entity that can participate in Transfers.

A Goal is **not** an Account. Goals must not appear in the Accounts list. Do not create fake Account rows for Goals. Do not require `goalId` on ordinary expenses.

Ordinary expense example:

- Type: Expense
- Category: Food → Delivery
- Account: HDFC
- No Goal relationship

Goal contribution and Goal withdrawal are **Transfers**, never Income or Expense. They do **not** consume spending budgets.

Supported transfer patterns:

1. Account → Account (ordinary)
2. Account → Goal (contribution / goal savings)
3. Goal → Account (withdrawal)
4. Goal → Goal (domain may support; initial UI need not expose it)

Transfer endpoint:

- `Account(accountId)`
- `Goal(goalId)`

Display: `HDFC ↔ Emergency Fund    ₹2,000`

**Negative Goal balance is forbidden.** If `withdrawalAmount > currentGoalBalance`, do not commit. Show available balance and the maximum withdrawable amount. Allow the user to change the amount or cancel. The failed mutation must roll back atomically.

Default payment mode:

- Account → Account and credit-card settlement: `Bank Transfer` (user may change to a compatible mode)
- Goal contribution / withdrawal: `Internal Transfer` (may be hidden from the ordinary picker)

Each Goal has an auto-created linked category `Goals → <Goal Name>`. Goal transfers use that category for identity in reporting. The Goal entity holds target, date and reconstructible progress. Do not store a second independent authoritative Goal balance.

Goal savings (period) = net money transferred into Goals during the period (contributions minus withdrawals).

---

## ADR-024 — Authoritative financial state is event-sourced (R1)

**Source of truth is Option B, not Option A.**

Authoritative data:

- Opening balances (and credit-card opening outstanding, if set at account creation)
- Financial events: Income, Expense, Transfer (including Goal and card settlement), Balance Adjustment
- Configuration that is not a transaction: credit limit, bill-generation day, category budgets, carry-forward budget allocations

Derived financial state **must** be calculable from authoritative data:

1. Account balance = opening balance + account-affecting events
2. Goal current amount = Goal contributions − Goal withdrawals (and Goal → Goal effects)
3. Credit-card outstanding = opening outstanding + charges/credits ± card adjustments − settlements/payments, per domain rules
4. Net Available Balance and Net Worth = formulas in ADR-032
5. Budget remaining = category budgets − eligible spending
6. Safe-to-Spend = ADR-031

`currentBalance`, `currentAmount` and `outstandingAmount` are **not** independent sources of truth.

If performance requires stored values, they exist only as **non-authoritative caches / materialized views**. They must be:

- Updated only inside the same atomic mutation as the events (Q2)
- Safely invalidatable
- Fully reconstructible after restart, migration, import, merge, restore, edit and delete

Reconciliation tests must compare cached values to freshly calculated values.

Opening balance is not income. Credit-card limit is not a transaction. Budget allocation and carry-forward are budget-state transitions, not transactions.

---

## ADR-025 — Database: Drift + SQLite + SQLCipher (Q10)

Stack:

`Flutter → Domain/Application → Drift repositories → SQLite / SQLCipher`

- No Isar, Firebase, Supabase, Realm, Hive, or other persistence unless this ADR is explicitly revised
- Encryption key in platform secure storage, never inside the database file
- Versioned, tested migrations
- Multi-row financial writes use database transactions
- Domain invariants are enforced in the domain/application layer and supported by database constraints where appropriate

---

## ADR-026 — Money is integer minor units

Never use floating-point for monetary storage or calculation. Store amounts as integer minor units. Currency determines precision. Search and comparisons use those integers. Display formatting is not financial truth.

---

## ADR-027 — Allocation sign convention (R6, A8)

All allocation amounts are **positive** and **> 0**. Direction is `SOURCE` or `DESTINATION`, never a negative amount.

Transfer invariants:

1. At least one source and one destination
2. Each allocation references exactly one endpoint (Account **or** Goal)
3. Sum(source amounts) = Sum(destination amounts)
4. Domain validation is authoritative; UI validation is supplementary
5. Mutations are atomic

Expense/Income category splits: sum of category allocation amounts = transaction total. Transfers do not use category splits. A Goal-linked transfer has a single Goal category for identity, not a category split.

The initial UI may simplify many-to-many transfers even if the domain supports them.

---

## ADR-028 — Balance Adjustment (R5, Q7)

Balance Adjustment is a traceable financial event, semantically distinct from Expense, Income and Transfer.

UX: Account → More → Adjust Balance. Not a primary `+` type. Show current tracked balance, actual balance, calculated adjustment, and copy: this adjustment is not income, spending, or savings.

- Asset accounts: positive adjustment increases balance; negative decreases it
- Credit cards: positive adjustment increases outstanding; negative decreases it
- Goals **must not** accept Balance Adjustments

Adjustments affect account/card reconstructed balances and therefore Net Worth. They must not affect income, expenses, category spending, budgets, savings, goal savings, trends, or Safe-to-Spend.

---

## ADR-029 — Credit-card liability model (R4, A4, A10, Q3, Q4)

Do not persist both `currentBalance` and `outstandingAmount` as competing truths. Do not persist `currentBalance = -outstandingAmount`.

Authoritative: opening outstanding (if any), card purchases/charges, credits, partial payments, settlements, card Balance Adjustments, statement snapshots.

Derived:

- `outstandingAmount`
- `availableCredit = creditLimit - outstandingAmount`

Partial Bank → Card payments are allowed at any time and reduce current outstanding.

On configured bill-generation day:

1. Capture current outstanding as that cycle’s statement snapshot (idempotent on `profileId + accountId + statementCycle`)
2. Notify if enabled
3. Present guided settlement UX

V1 does not reproduce the bank’s due dates, interest, or minimum payment. After the snapshot, later purchases belong to the next cycle. Settlement UX targets the applicable generated statement balance. Partial payments still reduce **current** outstanding.

Repayment warning (currency-scoped, never blocks):

`EligibleRepaymentFunds = sum of Bank balances in the same currency` (exclude Cash, Cards, Goals, other currencies)

Warn if `EligibleRepaymentFunds < currentOutstanding + newPurchaseAmount`.

---

## ADR-030 — Recurring occurrence idempotency (R8, A12)

Primary key of an occurrence: `(recurringTransactionId, scheduledOccurrenceDate)` with a database uniqueness constraint.

`lastExecutedAt` is metadata only.

Statuses: `PENDING`, `RECORDED`, `SKIPPED`, `FAILED`.

Create the generated transaction and mark `RECORDED` atomically. Duplicate OS/notification/retry must not create a second transaction. Missed months are separate occurrences, never collapsed. Skipped stays skipped. Failed remains retryable under the same key.

Edit prompt: apply to all future? If yes, deactivate the old rule at the split point and create a new rule for future occurrences. Historical recorded transactions never change.

---

## ADR-031 — Safe-to-Spend (A1)

Currency-scoped. Never negative (display zero).

```text
SafeToSpend = MAX(0,
  (TotalMonthlyBudget - EligibleSpentToDate - RemainingScheduledBudgetedRecurring)
  / DaysRemainingInclusive)
```

- `TotalMonthlyBudget` = sum of category budgets for that month and currency (no unallocated pool)
- `EligibleSpentToDate` = spending that consumes allocated category budgets
- Unbudgeted spending does not increase remaining planned budget
- `DaysRemainingInclusive` = today through last calendar day of the month, inclusive

---

## ADR-032 — Dashboard aggregates and net worth (A2, A3)

**Available Budget (View A hero)**

```text
AvailableBudget = TotalMonthlyBudget - EligibleSpentToDate
```

May be negative. Never blocks spending.

**Net Available Balance (View B hero)**

```text
NetAvailableBalance = sum(Bank balances) + sum(Cash balances)
```

Credit cards excluded. Goals excluded from this liquid figure.

**Net Worth**

```text
NetWorth = Bank balances + Cash balances + Goal balances - Credit Card outstanding
```

Credit-card limits are not assets. Settlement does not change Net Worth by itself (asset decreases, liability decreases).

**Double-counting rule:** Goal money must not be counted twice. After an Account → Goal transfer, the source Account has already decreased; the Goal balance is the continuation of that money. Including Goal balances in Net Worth does **not** double-count. Omitting Goal balances after the transfer would drop owned money from Net Worth.

A3’s example that Goal money remains inside the HDFC balance after contribution is inconsistent with R2’s transfer mutation (`HDFC ₹50,000 → ₹48,000`). R2 + ADR-023 take precedence for the mutation; this ADR takes precedence for Net Worth so the moved savings remain owned wealth.

Multi-currency dashboards show per-currency sections. Never silently convert.

---

## ADR-033 — Income requires a category (A9)

Income cannot be committed without a category.

---

## ADR-034 — No unallocated budget pool; carry-forward is category-allocated (A5, A6, A11, Q9)

There is no unallocated budget pool in the data model, calculations, UI, insights, or backup.

```text
TotalMonthlyBudget = SUM(category budgets for month + currency)
```

A budget attaches to exactly one `categoryId`. Do not attach a budget to a parent and its children at the same time. Parent totals are display aggregations; spending is not counted twice.

Carry-forward is a budget-state transition, not a transaction.

1. For each category: `Unused = MAX(0, CategoryBudget - EligibleCategorySpend)`
2. Overspent categories contribute 0
3. Ask whether to carry forward the total unused
4. If no: unused expires
5. If yes: user must allocate the **entire** amount to one or more categories in the new month before completion
6. Store base budget vs carry-forward allocation separately for history

---

## ADR-035 — Import / merge (R7, Q6)

Merge authoritative events and configuration, then recalculate derived state. Never merge cached balances as truth.

- Identical ID + identical payload: keep one
- ID only in one set: union
- Safe metadata: newer `updatedAt` wins
- Collections: union by ID after per-entity resolution
- Financial identity conflicts (amount, type, endpoints, currency, material date, adjustment payload): **user must choose**; do not silent-win
- Non-financial transaction metadata (notes, tags) may use `updatedAt` if financial identity is unchanged
- Archived vs active: do not silently resurrect; conflict or preserve archive per product archive rules
- Replace / Merge / New profile modes as specified
- Merge is atomic; failure rolls back completely
- Before Replace or Merge, retain a lossless restore point
- Preserve a merge-conflict audit (entity ID, local, imported, decision, timestamp) in lossless backup

---

## ADR-036 — Lossless backup format

Dedicated encrypted `.pfbackup`. Not CSV/Excel. Versioned independently of app version and DB migration version.

```text
{
  "format": "pocket_friendly_backup",
  "formatVersion": 1,
  "appVersion": "...",
  "exportedAt": "...",
  "data": { ... }
}
```

Validate fully, then restore atomically. Failed restore must leave the existing database untouched. Profile image and local-only identity data remain excluded.

---

## ADR-037 — Onboarding composes production use cases

Production onboarding must not use stub domain logic or duplicate models. Visual prototypes may use mocks; production onboarding is Phase 12 after the configured features exist.

---

## ADR-038 — Implementation dependency rule

Never bypass a hard dependency with temporary production business logic. Isolated UI mocks must be marked non-production. If a dependent feature reveals an unresolved rule, stop and flag it.

Hard dependencies:

1. Splits → transaction + allocations + atomic mutation
2. Goals → transaction/transfer engine + Goal ↔ category link + Goal transfer invariants
3. Card settlement → transfer engine + outstanding + statement model
4. Safe-to-Spend → budget engine + recurring projection
5. Insights → frozen definitions of income, spending, transfers, savings, goals, budgets, card liability
6. Natural language → domain query/use-case layer; never direct table access
7. Lossless backup → frozen schema, format version, stable IDs, validation

Soft: Dashboard and visual onboarding may be incremental if they consume real domain services or are explicitly mocked.
