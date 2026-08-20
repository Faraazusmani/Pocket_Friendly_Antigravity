# Pocket Friendly — Master Product Requirements & Technical Specification

## 1. Product Definition
Pocket Friendly is a premium, intelligent, satisfying and private personal money manager for anyone managing personal finances.

**Core principle:** Pocket Friendly does not control your money. It helps you understand it.

Priority order: Premium → Intelligent → Satisfying → Minimal → Private → Trustworthy → Calm → Motivating → Serious → Playful.

Avoid clutter, childishness, excessive colour, gamification, cloud dependence and external financial recommendations.

## 2. Platform & Architecture
- Flutter/shared codebase.
- Android first; iOS later without rewriting the product.
- Entirely local-first/offline-first.
- No login/account required.
- No permanent cloud storage.
- No financial data leaves the device during normal operation.
- Encrypted local database.
- No recurring backend/API cost for core functionality.
- Email export is the principal network-dependent financial-data action.

## 3. Security & Privacy
- One app-wide PIN/device-authentication lock.
- Privacy Mode hides all monetary values while preserving layout.
- Notifications are optional; the app remains fully functional without them.
- Profile images and explicitly local identity data are excluded from import/export.

## 4. Navigation
Primary state:
`Home | Transactions | Explore`    `+`

Secondary state:
`Goals | Categories | Insights`    `+`

Explore transforms the navigation pill in place; it never expands upward. Tapping outside returns to primary state. The `+` control is visually separated and persistent, and always opens Record Transaction.

## 5. Onboarding
Sequence:
1. Name
2. Privacy introduction
3. Financial priorities
4. First account
5. Monthly income
6. Categories
7. Category budgets
8. Goals
9. Recurring payments
10. Notifications
11. Privacy confirmation
12. Completion

Onboarding configures the user's environment rather than acting as a marketing carousel. Optional setup may be skipped where appropriate. All setup is local.

## 6. Dashboard
Header: profile/name, privacy control, month/year selector.

Snapshot has two swipeable views:
- Budget view: hero = Available Budget; supporting = Total Budget.
- Balance view: hero = Net Available Balance; supporting = Income and Spent.

Changing the month changes only the Snapshot and subtly highlights that component. Goals, recent transactions and other Dashboard content remain current.

Also show Safe-to-Spend, budget warnings, current goals and five recent transactions.

## 7. Safe-to-Spend
Currency-scoped. Never display a negative daily amount.

`MAX(0, (TotalMonthlyBudget − EligibleSpentToDate − RemainingScheduledBudgetedRecurring) ÷ DaysRemainingInclusive)`.

Planned/recurring budgeted expenses are considered. Unbudgeted spending is excluded from the remaining planned budget. Example: “Safe to spend ₹1,000/day to stay within budget.”

## 8. Accounts & Net Worth
Account types: Bank, Cash, Credit Card.

Account creation supports name, opening balance, currency and icon. Credit cards additionally require credit limit, opening outstanding and bill-generation day. Deleting an account archives it and preserves history. Opening balance is not income. Credit-card limit is not a transaction. Manual balance edits create a traceable Balance Adjustment (not income/expense/savings).

Net Available Balance = Bank balances + Cash balances.

Net Worth = Bank balances + Cash balances + Goal balances − Credit-card outstanding.

## 9. Credit Cards
Credit cards are first-class financial objects.

On bill-generation day, snapshot the current outstanding as that cycle’s statement (idempotent) and show a local settlement prompt. Partial Bank → Card payments are allowed at any time.

Settlement flow:
1. Select Settle.
2. Show the applicable statement/outstanding amount.
3. Select bank account.
4. Confirm.
5. Bank balance decreases.
6. Card outstanding decreases by the settlement amount (full guided settlement pays the statement).
7. Available credit is restored by the amount repaid.
8. Record a specialized transfer such as `Settled Credit Card Bill`.

Settlement is not another expense.

Before a credit-card purchase, if eligible same-currency bank funds (cash and Goals excluded) cannot cover current outstanding plus the new purchase, warn. The user may proceed.

## 10. Transactions
Exactly three primary types: Expense, Income, Transfer.

Every transaction requires a payment mode.

### Record Transaction
Fields: type, amount, category, account, date, payment mode, notes, tag, recurring.

### Split categories
Secondary option under Category: “Does this expense contain multiple categories?” If enabled, a bottom sheet lets the user select multiple categories and enter amounts.

### Split accounts
Secondary option under Account: “Did you pay from two different accounts for this transaction?” If enabled, a bottom sheet lets the user select multiple accounts and enter amounts.

Both splits may be enabled simultaneously. Allocation totals must equal the transaction total.

Editing any applicable field triggers full recalculation. Deleting reverses all dependent effects while preserving required history.

## 11. Payment Modes
Defaults: UPI, Debit Card, Credit Card, Cash, Bank Transfer.

Users can add/edit/delete modes. A transaction cannot be saved without a mode.

Credit Card accounts only allow Credit Card; Cash accounts only allow Cash; bank accounts allow compatible bank modes.

## 12. Categories & Tags
Normal hierarchy: Parent Category → Subcategory. Maximum two levels.

Goals appear in the category tree as `Goals → <Goal Name>` (two levels). Each Goal also has a separate Goal entity. Ordinary expenses are not Goal-related.

All active categories/subcategories remain visible regardless of spending or overspending.

Users may create, edit, rename, delete and customize categories. Renaming updates displayed names in historical records. Deletion archives entities so history remains valid.

Tags are managed inside Categories. A transaction has zero or one tag.

## 13. Budgets
There is one budget system based on category budgets.

`Total Monthly Budget = Sum of category budgets`. There is no unallocated budget pool. Every budgeted amount belongs to a category.

Users can exceed category or total budgets. Pocket Friendly warns but never blocks.

At the start of a month, ask whether unused (positive) budget should be carried forward. If accepted, the user must allocate the entire amount to one or more categories in the new month. Carry-forward is a budget-state transition, not a transaction.

## 14. Goals
Goals can represent any manually managed objective, including standard savings goals, EMI and SIP concepts.

Creation: name, icon, target amount, target date, description, optional contribution/reminder.

No target date → one-year projection.

Contribution is a Transfer: Account → Goal (not an expense, not budget spend). Withdrawal is a Transfer: Goal → Account. A Goal balance must never become negative.

If target date passes, ask for a new date rather than silently changing it.

Monthly insights distinguish income, actual spending, Goal savings, account savings and total savings.

## 15. Recurring Transactions
User chooses frequency and whether the item is a Reminder or Automatic Recording.

If a scheduled day does not exist in a month, use that month's last day.

If automatic recording cannot be safely completed, do not record and notify the user.

When editing a recurring transaction, ask whether all future occurrences should use the updated configuration. Historical recorded occurrences never change. Recurring execution is idempotent per scheduled occurrence date.

## 16. Insights
Insights are local, deterministic and strictly based on the user's financial data. No external AI or financial recommendations.

Include savings rate, average daily spend, biggest expense, six-month income/expense/savings trend, top expense categories, spending spikes, unusual transactions, recurring expenses, category trends, budget risks, goal progress risks, month-over-month changes and savings changes where data is sufficient.

Insights support month/year filters.

## 17. Natural-Language Assistant
Chat bar sits immediately above the bottom navigation on Insights.

It answers questions about transactions, categories, accounts, budgets, goals, income, spending, savings, trends, tags, payment modes and dates.

Initially it may prepare transaction-creation actions. Example: “Add ₹500 income from freelancing” becomes a structured intent and opens Record Transaction with fields prefilled. The user must review and manually Save.

The assistant never commits a financial mutation directly. Action permission is granted once and manageable later.

Voice is optional and must use on-device/offline speech recognition. If unavailable, voice is unavailable. No speaker response is required.

## 18. Search
Search notes, tags and amounts. Amount uses contains matching: `500` matches 500, 1500, 2500, 5000. `500-1000` means an amount range.

Filters: category, tag, payment mode, date range and transaction type.

## 19. Import & Export
Exports:
1. Lossless Pocket Friendly backup.
2. CSV.
3. Excel.

Import choices:
- Replace everything.
- Merge.
- Import to a new profile.

Never create duplicates. Preserve stable IDs, relationships, archived entities, historical states, profiles, currencies, budgets, goals, recurring rules and transactions.

## 20. Profiles
Multiple independent local profiles are supported. Each profile has independent financial data. One app-wide lock protects the application.

## 21. Multi-Currency
Users choose a currency during setup and may change the default later.

Historical transactions retain their original currency. Changing default currency affects future transactions only. If switching from INR to USD, provide a convenient path to create a new account in USD.

Do not use external exchange rates or silently convert historical data. Do not combine unrelated currencies in calculations.

## 22. Regionalisation
English only initially. INR uses Indian formatting. Other currencies use appropriate international/American formatting. Dates use formats such as `17 Aug 2026`. Year means January–December.

## 23. Notifications
Local notifications may cover budget overspending, monthly summary, monthly budget reset, recurring reminders, goal reminders, credit-card bill generation/settlement and relevant financial warnings.

The app remains fully functional if notification permission is denied.

## 24. Design Direction
Apple-quality benchmark without copying Apple's UI.

Use OLED black, shades of black/white, one rich blue or green accent, selective glassmorphism, opacity, layered surfaces, ample whitespace, premium grotesk typography and Lucide icons.

Candidate fonts: Hanken Grotesk, Host Grotesk.

## 25. Motion & Haptics
Use subtle motion and haptic feedback for meaningful actions including save, edit, delete, onboarding completion, goal actions, credit-card settlement, filter changes, navigation transformation and import/export completion.

Never overuse haptics.

## 26. Empty/Error States
Prefer typography and icons over large illustrations. Keep states calm, concise and actionable.

## 27. Product Boundaries
No bank integrations, UPI integrations, automatic bank sync, investment/stock/mutual-fund tracking, credit-score tracking, cloud financial storage or external financial recommendations.

## 28. Success Criteria
Users can set up quickly, record transactions accurately, understand spending/budget/credit-card liability, track goals, query history, export/restore data, operate offline and trust that financial data remains private.

## 29. Implementation Rule
The PRD is the product source of truth for intent. Where DECISIONS.md records a later explicit resolution, that decision takes precedence. The companion architecture, data model, business rules, design system, decisions, agent guidelines and feature specifications turn the product into an implementation contract. Do not ask an agent to build the entire app in one pass.
