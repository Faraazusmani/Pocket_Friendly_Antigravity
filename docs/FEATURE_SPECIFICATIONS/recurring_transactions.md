# Recurring Transactions

Modes: Reminder or Automatic Recording.

Frequency is user-selected. If a scheduled day does not exist in a month, use the month’s last day.

## Idempotency
Occurrence identity: `(recurringTransactionId, scheduledOccurrenceDate)` with a database uniqueness constraint.

`lastExecutedAt` is metadata only.

Statuses: PENDING, RECORDED, SKIPPED, FAILED.

Record the transaction and mark RECORDED atomically. Duplicate OS/notification/retry must not create another transaction. Crash after insert / before metadata: repair from occurrence identity or `createdTransactionId`. Crash before insert: retryable.

Missed months are separate occurrences, never collapsed.

Skipped stays SKIPPED. Failed stays retryable under the same key.

Notifications are not proof of recording.

## Edit
Ask: apply updated changes to all future transactions?

If yes: deactivate old rule at split; new rule from next occurrence; historical recorded transactions unchanged.

If automatic recording cannot safely execute, do not record, mark FAILED, notify.

## Required tests
Normal execution; duplicate OS/notification; restart; crash before/after transaction; crash before metadata; retry after failure; missed and multiple missed; skip; edit future vs history; uniqueness constraint; import/backup preservation.
