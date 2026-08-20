# Notifications

Local notifications only. Core app functionality must not require notification permission.

May cover:

- Budget overspending
- Monthly summary
- Monthly budget reset / carry-forward prompt
- Recurring reminders
- Goal reminders
- EMI/SIP reminders
- Credit-card bill generation / settlement
- Recurring auto-record failure

## Recurring
OS may deliver a reminder more than once. Delivery must not create a transaction. Recurring occurrence state in the database is authoritative (see `recurring_transactions.md`).

## Credit cards
Bill-generation notification follows idempotent statement snapshot rules.

## Privacy
Notification copy must not leak monetary values to untrusted surfaces beyond what the user enabled. Financial data must not leave the device during normal operation.
