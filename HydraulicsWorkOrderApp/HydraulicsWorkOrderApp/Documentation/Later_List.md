 # 🕒 Later List — Hydraulics Work Order App

This file tracks enhancements/cleanup tasks that are **not ready to implement yet** but should be revisited.

---

## Dropdown Catalogs
- [ ] Update `size` field to conditional visibility (only if type = Cylinder) with proper ranges (`< 24"`, `24" - 36"`, `> 36"`).
- [ ] Update `color` field to include both names and hex codes; implement color picker for "Other".

---

## UI / UX
- [ ] Align DropdownManagerView read-only mode visuals for Managers.
- [ ] Add visual indicator for “catalog-managed” fields in forms.

---

## Data Model
- [ ] Confirm `ReasonsForService` catalog syncing between Firebase and local SQLite.
- [ ] Add schema enforcement for catalog-managed fields.

---

## Testing
- [ ] Test color picker fallback on “Other”.

---

## Auto-Log Out
- [ ] Users should be logged out after 1 minute of inactivity

---

👉 Add items here as they come up. When ready, pull tasks into the Build Plan or Checklist.
