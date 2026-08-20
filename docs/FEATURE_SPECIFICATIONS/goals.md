# Goals

Goals are manually managed objectives (including EMI/SIP concepts). A Goal is **not** an Account and must not appear in the Accounts list.

## Category link
Reserved parent `Goals`. Creating a Goal auto-creates `Goals → <Goal Name>`.

Ordinary spending (e.g. Swiggy → Food → Delivery) has **no** Goal relationship.

## Creation
Name, icon, target, target date, description, optional contribution/reminder.

No target date → one-year projection. Expired date → user must set a new date.

## Balance
Reconstruct from Goal-related Transfers only. Optional cache is non-authoritative. No Balance Adjustments on Goals.

## Contribution
Transfer: Account → Goal.

Type: Transfer  
Category: Goals → Emergency Fund  
Source: Account(HDFC)  
Destination: Goal(Emergency Fund)  
Payment mode: Internal Transfer (default)

HDFC decreases; Goal increases. Not expense. Does not consume budget. Increases Goal savings.

Display: `HDFC ↔ Emergency Fund    ₹2,000`

## Withdrawal
Transfer: Goal → Account. Same category identity. Decreases Goal savings.

**Invariant:** Goal balance cannot go negative. If requested amount > current balance, reject, show available/max, allow edit or cancel. Atomic rollback.

## Goal → Goal
May be supported internally; initial UI need not expose it.

## Insights
Distinguish income, actual spending, Goal savings, account savings, total savings.

## Required tests
- Account → Goal
- Goal → Account
- Goal → Goal if supported
- Balance and progress reconstruction
- Edit and delete of Goal transfers
- Net Worth / Net Available Balance (no double-count)
- Budget exclusion
- Savings reporting
- Goal category filtering
- Ordinary expenses not associated with Goals
- Valid withdrawal, withdrawal equal to balance, withdrawal greater than balance, zero/invalid
- Atomic rollback
- Import/export preservation
