# Pocket Friendly — Architecture Specification

## 1. Purpose
Technical architecture for Pocket Friendly: Android-first, future iOS, Flutter, local-first, offline-capable, privacy-preserving.

## 2. Architectural Goals
- One shared Flutter codebase.
- Android-first release with future iOS support.
- Core functionality works without internet.
- Financial data never leaves the device during normal operation.
- No mandatory cloud backend or recurring backend cost.
- Strong local data integrity.
- Deterministic and testable financial calculations.
- Explicit user confirmation for financial mutations.

## 3. Application Layers
Use:
Presentation → Application/State → Domain → Data → Local/Platform Services.

### Presentation
Screens, widgets, navigation UI, user input, animations, haptics and accessibility. No financial calculations.

### Application/State
Coordinates user actions, loads domain data, manages screen state and invokes use cases.

### Domain
Entities, value objects, use cases, validation, transaction rules, budgets, goals, credit cards, recurring rules, insights and calculations. Must not depend on Flutter widgets or concrete database implementations.

### Data
Repository implementations, database mapping, serialization, import/export and persistence.

### Local/Platform Services
Encrypted storage, local notifications, app lock/biometrics, haptics, file storage, native share/email, optional on-device speech recognition and background scheduling.

## 4. Feature-Oriented Structure
Recommended conceptual structure:
```text
lib/
  core/
    errors/
    result/
    routing/
    theme/
    design_system/
    security/
    storage/
    platform/
    utilities/
  features/
    onboarding/
    profiles/
    accounts/
    transactions/
    categories/
    budgets/
    goals/
    recurring/
    insights/
    assistant/
    notifications/
    import_export/
    settings/
```

## 5. Dependency Direction
Presentation → Application → Domain ← Data.

Repositories should be represented by interfaces and implemented in Data.

## 6. Navigation
Primary navigation:
`Home | Transactions | Explore`

Secondary navigation:
`Goals | Categories | Insights`

The `+` action is a separate persistent control and always opens Record Transaction.

Explore transforms the navigation pill in place. It does not expand upward. Tapping outside returns to the primary state.

## 7. Local Database
Stack: Drift + SQLite + SQLCipher. The encryption key is stored in platform secure storage, never in the database file.

Must support profiles, accounts, categories, goals, transactions, allocations, tags, payment modes, budgets (no unallocated pool), recurring rules, recurring occurrences, credit-card statements, notifications, archived entities, merge-audit records and stable IDs.

Versioned migrations are required. Do not introduce another persistence engine without a new ADR.

## 8. Atomic Financial Mutations
Operations changing multiple records must be atomic. Examples include expenses, goal contributions, credit-card settlement, transaction edits and deletions.

## 9. Derived Values
Authoritative data: opening balances/outstanding, financial events, and non-transaction configuration (limits, budgets, bill day).

Derived values include account balances, credit-card outstanding, available credit, Goal balances, Net Available Balance, Net Worth, category spending, budget remaining, Safe-to-Spend, savings and trends.

Stored balances may exist only as invalidatable caches. The app must rebuild financial state after restart, migration, import, merge, restore, edit and delete.

## 10. Background Work
Use local platform scheduling for recurring reminders, automatic transactions, credit-card bill reminders, monthly budget prompts and summaries. Respect OS scheduling constraints.

## 11. Security
Use encrypted local storage, secure key storage, app lock/device authentication and sanitized production logs. Never put financial data into analytics or remote crash payloads.

## 12. Natural-Language Assistant
Local rule-based pipeline:
`Input → Intent detection → Entity extraction → Validation → Result/prefilled UI`.

Mutation pipeline:
`Request → Parser → Structured intent → Validation → Transaction UI → User review → Save → Domain mutation`.

Parser must never directly mutate the database. Natural language must not query tables directly; it uses the domain/application query and use-case layer.

## 13. Voice
Voice is optional and must use on-device speech recognition. If reliable offline speech recognition is unavailable, disable voice rather than sending audio remotely.

## 14. Import/Export
Support:
1. Encrypted lossless Pocket Friendly backup (`.pfbackup`, versioned schema).
2. CSV.
3. Excel.

Import modes:
- Replace (validate, restore point, atomic commit).
- Merge (conflict-aware; financial conflicts require user choice).
- New profile.

Stable IDs are mandatory for duplicate detection. Restore validates fully before touching the live database.

## 15. Multi-Currency
Currency is stored at account/transaction context. Historical transactions retain original currency. Changing the default currency affects future transactions only. Do not use external exchange rates.

## 16. Testing
Unit-test all financial calculations and mutation logic. Add widget tests for critical screens and integration tests for complete financial workflows.

## 17. Performance
Use indexed queries, pagination, aggregation and lazy loading. Do not load an entire transaction history into memory for normal screens.

## 18. Offline Guarantee
Core features must not depend on network. Network-dependent actions must be explicitly limited to things such as email sharing, tutorial links and Play Store rating.

## 19. Decision Rule
When implementation is ambiguous, check PRD, BUSINESS_RULES, DATA_MODEL and DECISIONS first. Later explicit decisions in DECISIONS.md take precedence. Prefer local, deterministic and simple solutions. Never introduce a backend without approval. Never bypass a hard feature dependency with temporary production business logic.
