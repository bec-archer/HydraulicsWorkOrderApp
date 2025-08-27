# 🧱 Component Breakdown – Hydraulics Work Order App

*A SwiftUI-focused map of core UI components*

---

## 🖼 Main Views

### `ActiveWorkOrdersView`

* Grid layout showing active WorkOrders
* Pulls from Firebase/local cache
* Uses `WorkOrderCardView`

### `NewWorkOrderView`

* Customer lookup field
* New customer modal logic
* WO\_Item entry section (scan tag, upload photo, dropdowns, reason)
* Save → pushes to Firebase

### `WorkOrderDetailView`

* Lists all WO\_Items
* Shows NotesTimelineView
* Completion, flag toggle, close options (by role)

### `WorkOrderItemDetailView`

* Status controls (In Progress, Done, PASS/FAIL)
* Dropdown state review
* Add hours, parts, cost

### `SearchView`

* Multikeyword fuzzy search
* Inputs: name, phone, tagId, WO\_Number, status

---

## 🔧 Reusable Components

### `WorkOrderCardView`

* Customer name
* Image thumbnail
* Status badge
* Tappable phone
* Flag icon
* Timestamp & WO\_Number

### `DropdownField`

* Accepts schema version
* Color-coded
* Can disable if mismatched schema

### `PhotoPickerView`

* Uses camera or photo library
* Returns array of imageURLs

### `NotesTimelineView`

* Combines WO\_Note + WO\_Status entries
* Sorted by timestamp

### `StatusBadge`

* Color-coded by status
* Used in CardView + Detail

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
