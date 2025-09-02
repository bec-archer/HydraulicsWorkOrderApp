# ✅ Developer Checklist – Hydraulics Work Order App

*Updated: September 2nd, 2025 – Matches Final PRD & File Structure*

---

## 🔄 Functional Flow

* [ ] Tag Replacement Logic:

  * [ ] Admin/Manager can initiate tag reassignment
  * [ ] Prompt for reason + new tag ID
  * [ ] Log to `tagReplacementHistory`
  * [ ] Ensure old tags are searchable

* [ ] Customer Lookup logic:

  * [ ] First field is customer lookup (by phone or name)
  * [ ] If match found → autofill customer info
  * [ ] If no match → “+ Add New Customer” button appears
  * [ ] Modal opens with prefilled value
  * [ ] Tech enters: Company Name, Email, Tax Exempt \[t/f]
  * [ ] New customer saved and returned to WorkOrder form

* [ ] App opens to PIN-based login (4–8 digits)

* [ ] Logged-in user and role correctly persist

* [ ] WorkOrder creation supports 1+ WO\_Item(s)

* [ ] For each WO\_Item:

  * [ ] QR Code scanned (or bypass reason selected)
  * [ ] At least one image captured
  * [ ] Dropdowns selected and saved
  * [ ] Reason(s) for service checked
  * [ ] Reasons for Service are catalog-managed:
    * Admin/SuperAdmin can add/edit/deactivate options
    * Managers can submit change requests (read-only access in DropdownManagerView)

* [ ] WorkOrder number auto-generated in format: `YYMMDD-001`, `001-A`, etc.

* [ ] First image becomes card thumbnail

* [ ] All WO\_Items show up under WorkOrderDetailView

* [ ] Search supports: customer name, phone, WO\_#, tag, status

---

## 🧑‍🔧 Status Update + Test Logic

* [ ] Tech can mark WO\_Item:

  * [ ] In Progress
  * [ ] WO\_Item Done
  * [ ] Tested: PASS → enter Parts Used, Hours, Cost
  * [ ] Mark WorkOrder as Completed → card turns gray
* [ ] Tech can mark WorkOrder as Closed after completion
* [ ] FAIL logic:

  * [ ] First FAIL = logged, no alert
  * [ ] Second FAIL = triggers "PROBLEM CHILD"
  * [ ] Only Managers receive push
  * [ ] If tech inputting FAIL is not last updater, last updater is warned

---

## 👥 User Roles

| Feature                     | Tech | Manager | Admin | SuperAdmin |
| --------------------------- | ---- | ------- | ----- | ---------- |
| Add/Edit WorkOrder          | ✅   | ✅      | ✅    | ✅          |
| Mark WorkOrder Completed    | ✅   | ✅      | ✅    | ✅          |
| Mark WorkOrder Closed       | ✅   | ✅      | ✅    | ✅          |
| Override Parts/Hours/Cost   | ❌   | ✅      | ✅    | ✅          |
| View Closed WOs             | ❌   | ✅      | ✅    | ✅          |
| Add/Delete Users            | ❌   | ❌      | ✅*   | ✅          |
| Edit Dropdowns (general)    | ❌   | ❌      | ✅    | ✅          |
| Manage Reasons for Service  | ❌   | Request | ✅    | ✅          |
| Developer Toggles           | ❌   | ❌      | ❌    | ✅          |
| Restore Deleted WorkOrders  | ❌   | ✅      | ✅    | ✅          |
| Unlock Completed WorkOrders | ❌   | ✅      | ✅    | ✅          |
| Reassign/Replace Tag IDs    | ❌   | ✅      | ✅    | ✅          |

> *Admins cannot edit, activate/deactivate, or change any **SuperAdmin** account. Only SuperAdmin can manage SuperAdmin users.*

---

## 📦 Sync & Storage

* [ ] Dropdown versioning:

  * [ ] `WorkOrder` includes `dropdownSchemaVersion`
  * [ ] Value is frozen at WO creation using `DropdownSchema.currentVersion`
  * [ ] UI warns or disables edits if version mismatch is detected

* [ ] Conflict resolution logic in `SyncManager.swift`:

  * [ ] Uses `lastModified` to compare local vs remote WorkOrders
  * [ ] "Last write wins" strategy applied
  * [ ] Logs which version is kept

* [ ] Firebase Firestore active

* [ ] Images uploaded to Firebase Storage

* [ ] WorkOrder includes image URL fallback logic

* [ ] Local SQLite backup created

* [ ] Self-hosted sync pushes to `/sqlite_backups`

* [ ] SyncManager retries failed uploads

* [ ] Offline mode queue confirmed

---

## 🛠 UI / UX Checks

* [ ] Apple Notes style grid
* [ ] Yellow-accented theme from AppleNotesYellow\.json
* [ ] Tap targets are iPad-friendly
* [ ] Status badges are color-coded
* [ ] All major actions timestamped and attributed to user
* [ ] Completed WorkOrders appear grayed out
* [ ] Flagged WorkOrders show icon
* [ ] Deleted WorkOrders hidden unless Admin or above
* [ ] Fields always show `WorkOrder`, `WO_Item`, `WO_Note`, `WO_Status` — no "job" references
* [ ] Modal flows return to origin screen properly
* [ ] Fields support iPad keyboards + handwriting input
* [ ] Managers see DropdownManagerView in read-only mode with a Request Change option
* [ ] Admins can edit all dropdowns including Reasons for Service

---

## 🗃 Notes & History

* [ ] WO\_Status and WO\_Note stored separately
* [ ] Both displayed in `NotesTimelineView`
* [ ] User and timestamp shown on all entries
* [ ] Notes allow freeform input
* [ ] Status changes reflect dropdown + logic state
* [ ] Status: Checked In, In Progress, Done, Tested: PASS/FAIL, Completed, Closed

---

## 🧪 Developer Checks

* [ ] Codebase avoids "job" or legacy terms
* [ ] Developer toggles exist for:

  * [ ] Bypass tag scan enforcement
  * [ ] Disable login screen
* [ ] WO\_Number generation tested across midnight rollover
* [ ] Tag replacement logs are searchable by both old and new IDs
* [ ] Offline-first behavior tested
* [ ] Sample data can be reloaded on cold start
