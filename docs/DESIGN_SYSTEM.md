# Pocket Friendly — Design System Specification

## 1. Design Vision
Pocket Friendly should feel like a premium, Apple-quality consumer product without copying Apple's interfaces.

Personality:
**Premium · Intelligent · Satisfying · Modern · Private**

Never:
**Cluttered · Childish · Too colorful · Gamified · Cheap**

## 2. Principles
- Content first.
- Hierarchy over decoration.
- Generous whitespace.
- Layered surfaces.
- Glass/blur only where it improves depth or context.
- Restrained colour.
- Clear financial hierarchy.

## 3. Colour
Use:
- OLED black.
- Multiple black/charcoal surface tones.
- White and off-white.
- Muted text tones.
- One restrained rich blue or green accent.
- Restrained semantic status colours.

Use semantic tokens rather than raw colours:
```text
background.primary
background.secondary
surface.primary
surface.secondary
surface.elevated
text.primary
text.secondary
text.tertiary
border.subtle
accent.primary
accent.secondary
status.success
status.warning
status.error
status.info
```

The exact accent hue should be finalized during visual design exploration.

## 4. Dark Mode
Primary premium direction:
- OLED black base.
- Layered near-black cards/surfaces.
- White primary text.
- Muted secondary/tertiary text.
- Very subtle borders.

## 5. Light Mode
Use white/off-white backgrounds with subtle tonal card hierarchy and the same semantic colour system.

## 6. Typography
Candidate fonts:
- Hanken Grotesk.
- Host Grotesk.

Final selection should consider numeral quality, readability, weight range, licensing and platform consistency.

Semantic styles should include:
- Display.
- Large amount.
- Section heading.
- Card heading.
- Body.
- Secondary body.
- Caption.
- Label.
- Button.
- Numeric data.

## 7. Financial Numbers
Amounts should receive strong hierarchy, readable digit spacing and consistent currency formatting. Use tabular numerals where appropriate.

## 8. Spacing
Use a tokenized spacing scale rather than hardcoded arbitrary values:
`XS, SM, MD, LG, XL, XXL`.

Exact values should be finalized during visual design work.

## 9. Radius
Use semantic radius tokens:
`small, medium, large, pill, sheet`.

Cards and floating controls should feel soft but not excessively rounded.

## 10. Cards
Cards use:
- Clear hierarchy.
- Subtle surface contrast.
- Minimal borders.
- Controlled radius.
- Consistent padding.

Avoid unnecessary card nesting.

## 11. Glass
Use blur/translucency for floating navigation, sheets and overlays where appropriate. Glass must never reduce readability or accessibility.

## 12. Navigation
Navigation pill:
`Home | Transactions | Explore`

Secondary:
`Goals | Categories | Insights`

Action pill:
`+`

The action pill is visually separate and has its own surface and touch target.

## 13. Navigation Transformation
Explore transforms the navigation pill in place. It does not expand upward.

Default:
`Home | Transactions | Explore`

Secondary:
`Goals | Categories | Insights`

Tap outside the navigation area to return to primary state.

## 14. Primary Action
`+` always opens the universal Record Transaction sheet and remains available in all navigation states.

## 15. Buttons
Prioritize clear hierarchy, sufficient touch targets, high contrast, subtle press feedback and appropriate haptics.

## 16. Pills
Use for filters, segmented controls, navigation, status and tags. Avoid decorative pill overload.

## 17. Bottom Sheets
Use for:
- Record Transaction.
- Split categories.
- Split accounts.
- Filters.
- Goal contribution/withdrawal.
- Credit-card settlement.
- Insight details.
- Tag management.
- Secondary actions.

## 18. Dialogs
Use sparingly for destructive confirmations, major warnings and important permission explanations.

## 19. Toasts
Use for short contextual information. Do not use them for actions requiring a decision.

## 20. Forms
Minimize visible complexity, reveal advanced options progressively, use clear labels and preserve input through validation.

## 21. Transaction Entry
Priority:
1. Type.
2. Amount.
3. Category.
4. Account.
5. Date.
6. Payment mode.
7. Notes.
8. Tag.
9. Recurring.

## 22. Split Controls
Under Category:
`Does this expense contain multiple categories?`

Under Account:
`Did you pay from two different accounts for this transaction?`

These remain secondary controls until activated.

## 23. Progress
Use radial progress for Dashboard budget, circular progress for Goals, linear progress for Categories and subtle progress for onboarding.

## 24. Charts
Charts should be minimal, high-contrast and interactive. Avoid unnecessary decoration. Tapping a point should reveal exact values.

## 25. Empty States
Use typography, icons, concise copy and one obvious next action. Avoid large illustrations.

## 26. Privacy Mode
Replace monetary values with dots/placeholders while preserving layout dimensions where possible. Avoid layout shifts.

## 27. Motion
Motion should communicate state change, navigation, causality and completion. Examples include card flip, navigation transformation, sheet presentation and goal progress.

Avoid decorative continuous animation.

## 28. Motion Tokens
Standardize:
`motion.fast`, `motion.standard`, `motion.emphasized`.

Exact timing should be finalized during UI implementation.

## 29. Haptics
Use subtle haptics for meaningful actions:
- Save.
- Goal contribution.
- Navigation transformation.
- Toggle.
- Delete confirmation.
- Import completion.

Do not vibrate on every tap.

## 30. Icons
Use Lucide Icons with consistent stroke weight and optical alignment.

## 31. Accessibility
Support:
- Dynamic text sizing where practical.
- Screen readers.
- Sufficient contrast.
- Minimum touch targets.
- Reduced motion.
- Clear focus/selection states.

Glass and opacity must never compromise accessibility.

## 32. Design Token Rule
Components must consume semantic design tokens. Avoid scattered raw values.

## 33. Evolution
New visual patterns should become reusable design-system components rather than one-off implementations.
