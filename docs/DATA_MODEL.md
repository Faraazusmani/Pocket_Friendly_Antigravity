# Pocket Friendly — Data Model Specification

## 1. Principles
- Every persisted entity has a stable unique ID.
- Financial records are never silently destroyed.
- Deleted entities become archived where historical relationships require it.
- **Transactions and opening balances are authoritative financial events/state.**
- Derived values must be recalculable from authoritative data after restart, migration, import, merge, restore, edit and delete.
- Cached `currentBalance` / `currentAmount` / `outstandingAmount` are non-authoritative materialized views only (ADR-024).
- Profiles isolate financial data.
- Currency is preserved at transaction/account/goal level.
- Monetary amounts are integer **minor units**. Never floating-point.
- There is **no** `UnallocatedBudgetPool`.

## 2. Profile
Fields:
- id
- name
- local profile image
- memberSince
- defaultCurrency
- createdAt
- updatedAt
- settings

Owns accounts, transactions, categories, tags, payment modes, goals, budgets, recurring rules, recurring occurrences, notifications, credit-card statements and merge-audit records.

## 3. Money
- `amountMinor: integer`
- `currency: ISO code` (INR, USD, EUR, …)
- Precision is currency-specific
- Display formatting is not source of truth

## 4. Account
Types: Bank, Cash, Credit Card.

Goals are **not** accounts.

Common fields:
- id
- profileId
- type
- name
- currency
- icon
- openingBalance (authoritative; not income; Bank/Cash)
- cachedCurrentBalance (optional materialized view; reconstructible)
- status
- createdAt
- updatedAt
- archivedAt

Credit-card fields (configuration, not transactions):
- creditLimit
- openingOutstanding (authoritative initial liability if entered at creation; not an expense)
- billGenerationDay
- cachedOutstandingAmount (optional materialized view; reconstructible)

Do **not** persist a competing `currentBalance` on credit cards. Do **not** persist `currentBalance = -outstandingAmount`.

Derived:
- outstandingAmount
- availableCredit = creditLimit − outstandingAmount

## 5. Category
Fields:
- id
- profileId
- parentCategoryId
- name
- icon
- status
- isSystem (reserved parent such as `Goals`)
- linkedGoalId (set on `Goals → <Goal Name>` categories)
- createdAt
- updatedAt
- archivedAt

Normal hierarchy is Parent → Subcategory (maximum two levels).

Reserved branch:

```text
Goals
  ├── Emergency Fund
  ├── New Car
  └── Europe Trip
```

Each Goal auto-creates `Goals → <Goal Name>`. Ordinary expenses do not require a Goal.

## 6. Goal
A balance-holding entity **and** a category identity. Not an Account.

Fields:
- id
- profileId
- categoryId (the `Goals → <Goal Name>` category)
- goalType (standard, EMI, SIP, or other concept)
- name
- icon
- targetAmount
- currency
- targetDate
- description
- cachedCurrentAmount (optional materialized view; reconstructible)
- status
- createdAt
- updatedAt
- archivedAt

Authoritative Goal balance = net Goal-related transfers.

Goals do not support Balance Adjustments.

## 7. Tag
Fields:
- id
- profileId
- name
- createdAt
- updatedAt
- archivedAt

A transaction has zero or one tag.

## 8. Payment Mode
Fields:
- id
- profileId
- name
- applicableAccountTypes
- isDefault
- isSystem (e.g. Internal Transfer)
- status
- createdAt
- updatedAt
- archivedAt

Default user-facing modes:
UPI, Debit Card, Credit Card, Cash, Bank Transfer.

System default for Goal transfers: Internal Transfer (may be hidden from the ordinary picker).

## 9. Transaction
A user-visible financial event.

Fields:
- id
- profileId
- type
- subtype (optional: `balanceAdjustment`, `creditCardSettlement`, …)
- date
- currency
- note
- tagId
- paymentModeId (required)
- recurringRuleId
- recurringOccurrenceId
- status
- createdAt
- updatedAt
- archivedAt

User-facing types: Expense, Income, Transfer.

Internal/special: Balance Adjustment (not offered on the primary `+` sheet).

Income requires at least one category allocation.
Expense supports category allocations (including splits).
Transfers do not category-split; a Goal transfer references the linked Goal category for identity.

## 10. Category Allocation
Used for Expense and Income (and Goal-transfer identity as a single category, not a split).

Fields:
- id
- transactionId
- categoryId
- amount (positive minor units)
- currency

When category splitting is active: sum of amounts = transaction total.

## 11. Transfer Endpoint Allocation
Replaces assuming every transfer endpoint is an Account.

Fields:
- id
- transactionId
- role: SOURCE | DESTINATION
- endpointType: ACCOUNT | GOAL
- accountId (if ACCOUNT)
- goalId (if GOAL)
- amount (positive minor units, always > 0)
- currency

Invariants: DATA_MODEL / BUSINESS_RULES / ADR-027.

Expense/Income account funding may use the same positive-amount + role model with Account endpoints only.

## 12. Transfer
Type = Transfer.

Patterns:
- Account → Account
- Account → Goal (contribution)
- Goal → Account (withdrawal)
- Goal → Goal (domain-supported; UI optional)

Not income. Not expense. Does not consume spending budget.

List display: `HDFC ↔ Emergency Fund    ₹2,000`

## 13. Balance Adjustment
Subtype of transaction, created from Account management.

Fields needed for audit: accountId (via allocation), amount, timestamp, optional note/reason.

Not applicable to Goals.

## 14. Credit-Card Statement
Fields:
- id
- profileId
- accountId
- statementCycle (year + month or equivalent unique cycle key)
- generatedOn
- statementBalance
- status
- createdAt

Uniqueness: `(profileId, accountId, statementCycle)`.

Generation is idempotent. Missed cycles are generated when the app next becomes active.

## 15. Budget
Belongs to profile, **one** categoryId, month/year and currency.

Fields:
- id
- profileId
- categoryId
- month
- year
- baseAmount
- carryForwardAmount
- currency
- createdAt
- updatedAt

`totalAmount = baseAmount + carryForwardAmount`.

No unallocated pool entity.

## 16. Recurring Transaction Rule
Fields:
- id
- profileId
- transactionTemplate
- frequency
- dayOfPeriod
- mode (Reminder | Automatic Recording)
- nextOccurrence
- active
- splitFromRuleId (when forked by “apply to all future”)
- lastExecutedAt (metadata only)
- createdAt
- updatedAt

## 17. Recurring Occurrence
Fields:
- id
- recurringTransactionId
- scheduledOccurrenceDate
- status (PENDING | RECORDED | SKIPPED | FAILED)
- createdTransactionId
- executedAt
- skippedAt
- failedAt
- createdAt
- updatedAt

Uniqueness constraint: `(recurringTransactionId, scheduledOccurrenceDate)`.

## 18. Notification
Fields:
- id
- profileId
- type
- scheduledAt
- payload
- status
- relatedEntityId

Notifications are local. Delivery is not proof that a recurring transaction was recorded.

## 19. Merge Conflict Audit
Fields:
- id
- profileId
- entityType
- entityId
- localPayload
- importedPayload
- userDecision
- decidedAt

Included in lossless backup.

## 20. Archived Entity
Accounts, categories, goals, tags and payment modes may be archived rather than destroyed when historical references exist.

Archived entities are excluded from active selection but remain usable for historical display. Archived accounts cannot receive new transactions.

## 21. Currency
Use stable currency codes. Do not assume one profile can only use one currency. Do not combine unrelated currencies.

## 22. IDs and Imports
IDs survive export/import/merge/device migration and are the primary duplicate-detection key.

## 23. Historical Naming
Historical records reference current entity names. If deleted, the archived entity remains available.

## 24. Profile Isolation
Every financial entity belongs to exactly one profile.

## 25. Derived Values
Must be reconstructible:

- Account balance
- Credit-card outstanding
- Available credit
- Goal balance / progress
- Net Available Balance
- Net Worth
- Category spending (no double-count parent/child)
- Budget remaining / Available Budget
- Safe-to-Spend
- Goal savings, account savings, total savings
- Income and eligible spending

## 26. Lossless Backup
Versioned `pocket_friendly_backup` / `.pfbackup`. Preserve IDs, relationships, archived states, recurring rules **and occurrences**, budgets with base vs carry-forward, statements, merge audit, currency, profiles. Do not treat cached balances as authoritative restore targets; restore events/config then recalculate.

Exclude profile image and local-only identity data.
