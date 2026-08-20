# Import & Export

## Exports
1. Encrypted lossless Pocket Friendly backup (`.pfbackup`, `format: pocket_friendly_backup`, `formatVersion` independent of app/DB versions).
2. CSV (not lossless).
3. Excel (not lossless).

Backup preserves profiles, accounts (opening state, not cached balances as truth), categories, tags, payment modes, transactions, allocations, Goals, recurring rules **and occurrences**, budgets (base + carry-forward), statements, notifications/reminders, archived entities, merge audit, stable IDs, timestamps. Recalculate derived financial state after restore.

Exclude profile image and local-only identity data.

Validate the entire backup before restore. Restore is atomic. Failure leaves the live database unchanged. Support backup-schema migration when `formatVersion` changes.

## Import modes
- **Replace everything:** restore point, validate, atomic replace.
- **Merge:** ADR-035. Metadata may use `updatedAt`. Financial identity conflicts require Keep Current / Use Imported. Do not silent-win amounts/types/endpoints/currency/material dates/adjustments. Do not silently resurrect archived entities. Recalculate derived state. Atomic; rollback on failure. Conflict audit persisted and included in backup.
- **Import to a new profile:** no merge with the current profile.

Never create duplicates when stable IDs match.

## Required tests
Identical dedupe; union of new records; metadata conflict; transaction amount/type/account/Goal transfer/adjustment conflicts; archived vs active; derived balance/Goal/outstanding recalculation; Replace; Merge; New Profile; duplicate prevention; failed merge rollback; restore after merge.
