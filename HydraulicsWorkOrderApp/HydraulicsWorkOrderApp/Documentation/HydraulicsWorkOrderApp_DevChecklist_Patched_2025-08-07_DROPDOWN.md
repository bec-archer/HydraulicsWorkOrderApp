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
  * [ ] Dropdowns selected and saved (dropdowns + dropdownSchemaVersion live on WO_Item)
  * [ ] Reason(s) for service checked
  * [ ] Reasons for Service are catalog-managed:
    * Admin/SuperAdmin can add/edit/deactivate options
    * Managers can submit change requests (read-only access in DropdownManagerView)

* [ ] WorkOrder number auto-generated in format: `YYMMDD-001`, `001-A`, etc.

* [ ] Card shows up to 4 images: the first image from up to four WO_Items (in item create order)

* [ ] All WO\_Items show up under WorkOrderDetailView

* [ ] Search supports: customer name, phone, WO\_#, tag, status

---

## 🧑‍🔧 Status Update + Test Logic

* [ ] Tech can mark WO\_Item:
  * [ ] In Progress
  * [ ] WO\_Item Done
  * [ ] Tested: PASS → enter Parts Used, Hours, Cost
  * [ ] Mark WorkOrder as Completed → card turns gray (roll-up derived from WO_Item statuses)
* [ ] Tech can mark WorkOrder as Closed after completion (roll-up flag/timestamp on WorkOrder)
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

* [ ] Each `WO_Item` includes `dropdownSchemaVersion` (snapshot at item creation)
* [ ] UI warns or disables edits on the item if version mismatch is detected

* [ ] Conflict resolution logic in `SyncManager.swift`:

  * [ ] Uses `lastModified` to compare local vs remote WorkOrders
  * [ ] "Last write wins" strategy applied
  * [ ] Logs which version is kept

* [ ] Firebase Firestore active

* [ ] Images uploaded to Firebase Storage

* [ ] Card thumbnails derive from items.imageUrls (first image per WO_Item, up to 4); optional WO image cache is non-authoritative

* [ ] Local SQLite backup created

* [ ] Self-hosted sync pushes to `/sqlite_backups`

* [ ] SyncManager retries failed uploads

* [ ] Offline mode queue confirmed

* [ ] WorkOrder.finalCost is a computed aggregate (cents) = sum of items.finalCost; recompute on any item cost change

* [ ] Collection-group index on `/workOrders/*/items`: (assignedToId ASC, status ASC) for “My Work Items”

* [ ] DeletedWorkOrdersView filters by `workOrders.isDeleted == true`

---

## 🛠 UI / UX Checks

* [ ] Apple Notes style grid
* [ ] Yellow-accented theme from AppleNotesYellow\.json
* [ ] Tap targets are iPad-friendly
* [ ] Status badges are color-coded
* [ ] All major actions timestamped and attributed to user
* [ ] Completed WorkOrders appear grayed out (based on roll-up Completed)
* [ ] Flagged WorkOrders show icon
* [ ] Deleted WorkOrders hidden unless Admin or above
* [ ] Fields always show `WorkOrder`, `WO_Item`, `WO_Note`, `WO_Status` — no "job" references
* [ ] Modal flows return to origin screen properly
* [ ] Fields support iPad keyboards + handwriting input
* [ ] Managers see DropdownManagerView in read-only mode with a Request Change option
* [ ] Admins can edit all dropdowns including Reasons for Service
* [ ] Card shows up to 4 thumbnails (first image from up to four WO_Items)
* [ ] DeletedWorkOrdersView lists `isDeleted == true`

---

## 🗃 Notes & History

* [ ] WO_Status and WO_Note stored separately
* [ ] WorkOrder-level notes stored in `/workOrders/{woId}/workOrderNotes`
* [ ] Item-level notes stored in `/workOrders/{woId}/items/{itemId}/itemNotes`
* [ ] Both displayed together in `NotesTimelineView` (merged + sorted by timestamp desc)
* [ ] User and timestamp shown on all entries
* [ ] Notes allow freeform input
* [ ] Status changes reflect dropdown + logic state (status & statusHistory live on WO_Item)
* [ ] Status: Checked In, In Progress, Done, Tested: PASS/FAIL at WO_Item level; WorkOrder uses roll-up Completed/Closed flags

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

### 🔧 Patch — PRD: Customer Emoji Tag

#### Customer Emoji Tag (new)
- Each Customer may have an optional **emoji tag** (e.g., 🔧, ⭐️).
- Any signed-in user can set/change/remove the emoji from **Customer Detail**.
- The emoji appears:
  - Next to the customer name in **WorkOrderCardView** and **WorkOrderDetailView**.
  - In **Customer lookup results** and the **Selected Customer Summary** in NewWorkOrderView.
- Validation:
  - Must be a single emoji (one visible symbol). If multiple characters are entered, keep the **first grapheme** and discard the rest.
