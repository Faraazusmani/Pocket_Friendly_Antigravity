# Pocket Friendly — AI Coding Agent Guidelines

## 1. Source of Truth
Before modifying code, read:
1. PRD.md
2. ARCHITECTURE.md
3. DATA_MODEL.md
4. BUSINESS_RULES.md
5. DESIGN_SYSTEM.md
6. DECISIONS.md

## 2. Product Decisions
Prefer explicit product decisions. Do not silently invent behaviour.

Where PRD text conflicts with a later ADR in DECISIONS.md, follow DECISIONS.md.

If a dependency reveals an unresolved business rule, stop the dependent feature and flag it.

Required tests listed in feature specifications must be added when that phase is implemented — not before the documented model exists.

## 3. Financial Safety
Never silently:
- Create financial records.
- Modify financial records.
- Delete financial records.
- Send financial data remotely.
- Introduce cloud dependencies.

Natural-language actions must prefill UI and wait for explicit user confirmation.

## 4. Code Quality
Prefer small focused classes, feature-oriented modules, pure domain calculations, explicit dependencies, strong typing, repository interfaces and testable use cases.

Avoid god classes, business logic in widgets, hardcoded design values, hidden global mutable state and unnecessary dependencies.

## 5. Before a Feature
1. Read the relevant feature specification.
2. Identify affected entities.
3. Identify affected business rules.
4. Identify affected screens.
5. Identify tests.
6. Reuse existing design-system components.

## 6. After a Feature
Report:
- Files created/modified.
- Dependencies added.
- Tests created.
- Tests executed.
- Architectural decisions.
- Unresolved issues.

## 7. Scope Discipline
Do not modify unrelated features without justification.

## 8. Testing
Every financial business rule must have unit tests. Critical user journeys require widget/integration tests. Do not mark work complete with failing tests.

## 9. UI
Use the design system. Do not invent a new visual language for an individual screen.

## 10. Completion
A feature is complete only when product behaviour, business rules, edge cases, tests, offline constraints and privacy constraints are satisfied.
