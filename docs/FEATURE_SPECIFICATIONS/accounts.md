# Accounts

Types: Bank, Cash, Credit Card. Goals are not accounts.

Creation: name, opening balance, currency, icon. Credit cards also require limit, opening outstanding and bill-generation day.

Opening balance is not income. Credit-card limit is not a transaction. Opening outstanding is not an expense.

Balances are reconstructed from opening state + events. Cached current balance / outstanding are optional materialized views.

Deletion archives the account, removes it from active selection and preserves historical transactions. Archived accounts cannot receive new transactions.

## Adjust Balance
Account → More → Adjust Balance.

Show tracked balance, actual balance, calculated adjustment, and: this is not income, spending, or savings.

Persisted as a Balance Adjustment event. Goals cannot be adjusted this way.

## Transfers
Positive amounts + SOURCE/DESTINATION. See `transactions.md`.

## Required tests
Positive/negative asset adjustment; positive/negative card adjustment; edit/delete; Net Worth; exclusion from income/expense/budget/savings/insights; Goal adjustment rejected; backup/import preservation.
