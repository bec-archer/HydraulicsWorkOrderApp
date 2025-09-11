# 🧱 Component Breakdown – Hydraulics Work Order App

*A SwiftUI-focused map of core UI components*

---

## 🖼 Main Views

### `ActiveWorkOrdersView`

* Grid layout showing active WorkOrders
* Pulls from Firebase/local cache
* Uses `WorkOrderCardView` (**indicator dots on cards: overlay on thumbnails + inline beside WO_Number; no StatusBadge on cards**)

### `NewWorkOrderView`

* Customer lookup field
* New customer modal logic
* WO_Item entry section (scan tag, upload photo, dropdowns, reason)
* Save → pushes to Firebase

### `WorkOrderDetailView`

* Lists all WO_Items (**each item row shows a StatusBadge; no indicator dots in this view**)
* Shows NotesTimelineView
* Completion, flag toggle, close options (by role)

### `WorkOrderItemDetailView`

* QR Codes section (chips list)
  * Shows each bound tag as a chip: short tag ID • **Primary** badge (if set) • Position Label (optional)
  * Actions per chip: **Set Primary** • **Edit Label** • **Unbind**
  * “**+ Add QR**” button opens the scanner from item context; first tag defaults to Primary if none exists, others default to Auxiliary
  * If a scanned tag is active on another item → prompt **Tag Reassignment**; on confirm, old binding deactivates, a new binding is added here, and a `tagHistory(event:"reassigned")` entry is appended
* Status controls (In Progress, Done, PASS/FAIL)
* Dropdown state review
* Add hours, parts, cost

### `SearchView`

* Multikeyword fuzzy search
* Inputs: name, phone, **Tag ID (active binding or previous via tagHistory)**, WO_Number, status

---

## 🔧 Reusable Components

### `WorkOrderCardView`

* Customer name
* Image thumbnails (up to **4** — first image from up to four WO_Items)
* **Indicator dots** (two placements):
  * **Overlay**: one dot at the **top-right** of each item thumbnail (one per WO_Item)
  * **Inline**: a summary row of up to **4** dots on the **same line as the WO_Number**
* Tappable phone
* Flag icon
* Timestamp & WO_Number
> **Note:** Cards never display tag chips. QR bindings (chips, labels, primary/aux) are shown only in item detail views.

### `DropdownField`

* Accepts schema version
* Color-coded
* Can disable if mismatched schema

### `PhotoPickerView`

* Uses camera or photo library
* Returns array of imageURLs

### `NotesTimelineView`

* Combines WO_Note + WO_Status entries
* Sorted by timestamp
* May include tag binding events from `tagHistory` (bound / unbound / reassigned) for audit visibility

### `StatusBadge`

* Color-coded by status (**source of truth** for status colors)
* **Used in detail screens only** (e.g., WO_Item rows in WorkOrderDetailView); **not** used on WorkOrder cards

- **Color mapping contract:** Indicator dot colors **must reference the StatusBadge semantic mapping** (no local color tables). Adding a new status only requires updating this mapping; dots inherit automatically.

### `WO_ItemTagListView` (NEW)

* Purpose: render and manage a WO_Item’s QR codes as chips
* Displays: short tag ID • **Primary** badge (if set) • Position Label (optional)
* Interactions:
  * Tap “+ Add QR” → open scanner; new binding defaults to Auxiliary (unless no Primary exists)
  * Per-chip overflow: **Set Primary** • **Edit Label** • **Unbind**
* Behavior notes:
  * Tag Reassignment flow: if a scanned tag is bound to another item, prompt **Tag Reassignment** (old binding deactivates, new binding added here, and a `tagHistory(event:"reassigned")` entry is appended)
  * Search is powered by active bindings and `tagHistory` (old IDs resolve to current owner)
* Accessibility: each chip has an accessibility label “Tag <shortId>, <Primary/Auxiliary>, label <Position>”

---

### ✅ Result
- `WorkOrderItemDetailView` now documents the **QR Codes** section and actions.
- `SearchView` inputs explicitly track **active bindings + tagHistory**.
- A reusable **`WO_ItemTagListView`** is defined for implementers.
- No other components or policies are changed (cards use **indicator dots**, detail views use **StatusBadge** as already documented).

---

## 🔒 Auth & Role Management

### `LoginView`

* PIN entry + role matching
* Shows error if PIN wrong

### `UserSelectionView`

* Optional user list by role (Admin)

---

## ⚙️ Admin Views

### `DropdownManagerView`

* Add/edit dropdown options
* Shows current schema version

### `UserManagerView`

* Add/remove users with roles

### `SettingsView`

* Toggles: Login enforcement, scan logic, sample reset

### `DeletedWorkOrdersView`

* Restore or permanently delete

### `SyncStatusView`

* Firebase + SQLite sync health

---

## 🧠 Manager Views

### `PendingApprovalView`

* Shows flagged WOs (e.g., PROBLEM CHILD)

### `ManagerReviewView`

* Modify parts/hours/notes if needed
* Completion override options
