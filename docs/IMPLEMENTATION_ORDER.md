# Pocket Friendly — Implementation Order

Never ask an agent to “build Pocket Friendly”. Give it one bounded phase, require tests, review the diff, then commit.

Phase gates are implementation checkpoints. Documented decisions in PRD, BUSINESS_RULES, DATA_MODEL and DECISIONS are fixed. If implementation conflicts with those decisions, stop and flag the conflict.

Onboarding visual prototypes may start earlier; **production onboarding is Phase 12**.

```text
Phase 0 Foundation
  → Phase 1 Core Data
    → Phase 2 Transaction Engine
      → Phase 2b Splits
        → Phase 3 Budgets
        → Phase 4 Goals
        → Phase 5 Credit Cards
          → Phase 6 Recurring
            → Phase 7 Dashboard (incremental OK if using domain services)
            → Phase 8 Insights
            → Phase 9 Search
              → Phase 10 Import/Export/Backup
                → Phase 11 Natural Language
                  → Phase 12 Onboarding
                    → Phase 13 Polish & QA
```

Hard dependencies must not be bypassed:

1. Splits → transaction + allocations + atomic mutation
2. Goals → transfer engine + Goal ↔ category link + Goal invariants
3. Card settlement → transfer engine + outstanding + statement model
4. Safe-to-Spend → budgets + recurring projection
5. Insights → frozen income/spend/transfer/savings/goal/budget/card definitions
6. Natural language → domain query/use-case layer
7. Lossless backup → frozen schema, format version, stable IDs, validation

---

## Phase 0 — Foundation

Flutter scaffold, clean architecture, DI, routing, design tokens, theme, Drift + SQLite + SQLCipher, secure key storage, migrations, Result/error types, repository interfaces, test harness, backup schema versioning strategy.

**Gate:** local-first only; key not in DB; domain/data/UI boundaries exist; backup versioning strategy exists.

## Phase 1 — Core Data

Profile, currency, Account types (including CC config fields), category tree including reserved `Goals` parent, Goal entity + linked category, tags, payment modes (including Internal Transfer), archive semantics, stable IDs.

**Gate:** archive-not-destroy; multi-currency without conversion; CC has no competing `currentBalance`; Goal is not an Account.

## Phase 2 — Transaction Engine

Expense, Income (category required), Transfer endpoints (Account|Goal), positive allocations + SOURCE/DESTINATION, payment mode, notes, tags, atomic mutation, edit/delete, reconstruction of balances, Balance Adjustment subtype, integer minor units.

**Gate:** reconciliation tests vs reconstructed balances; no mutation bypasses domain; transfer sum invariants tested. **Do not treat caches as truth.**

Required tests (non-exhaustive): allocation role/amount validation; zero/negative allocation rejected; missing source/destination rejected; edit/delete recalculation.

## Phase 2b — Transaction Splits

Category splits, account/funding splits, simultaneous splits. Atomic. UI copy as specified.

**Gate:** allocation sums equal transaction total; no partial writes.

## Phase 3 — Budgets

Category budgets, parent rollups without double-count, overspend warnings, Available Budget (A2), carry-forward with full category allocation, **no unallocated pool**.

Safe-to-Spend formula may be implemented here but **must not be marked complete** until Phase 6 provides remaining scheduled recurring projection.

**Gate:** every budget amount belongs to a category; carry-forward fully allocated; currency-scoped; overspend never blocks.

## Phase 4 — Goals

Goal CRUD, linked category, contribution/withdrawal transfers, progress, expired date prompt, Goal savings reporting, negative-balance rejection.

**Gate:** Goal transfers are not expenses; budgets ignore Goal transfers; ordinary expenses have no Goal; Net Worth/NAB do not double-count (ADR-032).

Required tests: Account→Goal; Goal→Account; Goal→Goal if supported; balance; progress; edit; delete; Net Worth; budget exclusion; savings reporting; Goal category filter; ordinary expense has no Goal; withdrawal = balance; withdrawal > balance rejected; zero/invalid; atomic rollback.

## Phase 5 — Credit Cards

Outstanding reconstruction, statement snapshot idempotency, bill-day notification, partial payments, guided settlement, available credit, repayment warning (A10).

**Gate:** cards excluded from NAB; liability in Net Worth; settlement is a transfer.

## Phase 6 — Recurring

Rules, occurrences, uniqueness `(ruleId, scheduledDate)`, reminder vs auto, missed occurrences, skip/fail, edit fork, notifications optional.

**Gate:** duplicate execution impossible; history immutable on edit; Safe-to-Spend remaining-recurring input now available.

## Phase 7 — Dashboard

View A: Available Budget + Total Budget. View B: Net Available Balance + Income/Spent. Safe-to-Spend, warnings, Goals strip, five recent transactions, privacy mode, per-currency sections. Consume domain aggregates only.

**Gate:** displayed numbers match domain services.

## Phase 8 — Insights

Local deterministic analytics including income, actual spending, Goal savings, account savings, total savings. No external advice.

**Gate:** definitions frozen and consistent.

## Phase 9 — Search

Notes, tags, amount contains and inclusive range, filters, integer minor units, currency-aware.

## Phase 10 — Import / Export / Backup

`.pfbackup` v1, restore validation, CSV/Excel, Replace / Merge / New profile, conflict UX, restore point, audit.

**Gate:** schema v1 frozen; failed restore leaves live DB untouched.

## Phase 11 — Natural Language

Local parser, domain queries, prefill Record Transaction, permission, optional on-device voice. Never commit; never touch tables directly.

## Phase 12 — Onboarding

12-step wizard composing production use cases only. No stub financial logic.

## Phase 13 — Polish & QA

Motion, haptics, empty/error, accessibility, performance, reconciliation, security, offline, multi-currency, recurring idempotency, financial edge cases.

---

## Parallel tracks (from Phase 0)

Design system, app lock/privacy mode, notification scheduling (optional for core function).
