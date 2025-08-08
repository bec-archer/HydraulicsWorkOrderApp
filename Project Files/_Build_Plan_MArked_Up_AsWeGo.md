# 📦 Build Plan – Hydraulics Work Order App

*Prioritized file creation and milestone tracking*
* Completed tasks marked with ✅
---

## 🧱 Phase 1: Core Setup

* [x] `AppState.swift`  ⟶ User session + routing ✅
* [x] `HydraulicsCheckInAppApp.swift`
* [x] `LoginView.swift` + PIN handling
* [x] `User.swift` model + role enum
* [x] `UserManager.swift` basic storage

---

## 🧾 Phase 2: WorkOrder Models & Storage

* [x] `WorkOrder.swift`

* [x] `WO_Item.swift`

* [x] `WO_Status.swift`

* [x] `WO_Note.swift`

* [x] `TagReplacement.swift`

* [x] `Customer.swift`

* [ ] `AuditLog.swift`

* [x] `WorkOrdersDatabase.swift`

* [x] `CustomerDatabase.swift`

* [x] `DropdownManager.swift`

---

## 🧪 Phase 3: WorkOrder Intake UI

* [x] `ActiveWorkOrdersView.swift`

* [x] `NewWorkOrderView.swift`

* [x] `WorkOrderCardView.swift`

* [x] `DropdownField.swift`

* [x] `PhotoPickerView.swift`

* [x] `SearchView.swift`

* [ ] `NewCustomerModalView.swift`

* [ ] `WorkOrderNumberGenerator.swift`

* [ ] `UIConstants.swift`

---

## 📝 Phase 4: Detail & Status Views

* [ ] `WorkOrderDetailView.swift`
* [ ] `WorkOrderItemDetailView.swift`
* [ ] `NotesTimelineView.swift`
* [ ] `StatusBadge.swift`

---

## 🔐 Phase 5: Role & Admin Tools

* [ ] `SettingsView.swift`
* [ ] `DropdownManagerView.swift`
* [ ] `UserManagerView.swift`
* [ ] `DeletedWorkOrdersView.swift`
* [ ] `SyncStatusView.swift`
* [ ] `PendingApprovalView.swift`
* [ ] `ManagerReviewView.swift`

---

## 🧪 Phase 6: Finalization & QA

* [ ] TestCases.md
* [ ] Developer Checklist ✅
* [ ] Firebase sync & retry logic
* [ ] Offline queue testing
* [ ] Tag reassignment searchability
* [ ] Sample data loader

---

## 🧩 Optional Enhancements

* [ ] Dark mode support
* [ ] Tablet-specific UI refinements
* [ ] Archive mode (read-only WorkOrders)
* [ ] Sync log viewer
