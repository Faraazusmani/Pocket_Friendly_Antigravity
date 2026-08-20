# Natural-Language Assistant

Location: chat bar immediately above bottom navigation on Insights.

## Queries
Answer questions about transactions, categories, accounts, budgets, goals, income, spending, savings, trends, tags, payment modes and dates.

## Actions
Initially transaction creation preparation only.

Example: `Add ₹500 income from freelancing` → Create Transaction / Income / ₹500 / Freelancing → open prefilled Record Transaction sheet.

User must review and Save. Parser never writes directly to the database. Natural language must use the domain query/use-case layer, not tables.

Income actions must include a category and cannot be committed without one.

Action permission is one-time and manageable in settings.

Voice is optional and local/on-device only. Disable it if offline recognition is unavailable.
