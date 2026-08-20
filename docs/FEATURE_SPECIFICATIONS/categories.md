# Categories & Tags

Normal hierarchy: Parent → Subcategory. Maximum two levels.

Reserved Goal branch (also two levels):

```text
Goals
  ├── Emergency Fund
  ├── New Car
  └── Europe Trip
```

Each Goal has a linked category. The Goal entity holds target/progress. Do not model a Goal as *only* a category, and do not model it as an Account.

All active categories remain visible regardless of spending.

Users can create/edit/rename/delete/customize ordinary categories. Renames update historical display names; deletions archive entities.

A budget attaches to a single categoryId, not to a parent and its children at once. Child spend rolls up to the parent for display without double-counting.

Tags are managed inside Categories. One tag per transaction.
