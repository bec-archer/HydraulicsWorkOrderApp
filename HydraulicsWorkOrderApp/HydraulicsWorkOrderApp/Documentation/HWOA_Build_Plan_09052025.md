# 📦 Build Plan – Hydraulics Work Order App

*Prioritized file creation and milestone tracking*

---

## 🧱 Phase 1: Core Setup

* [x] `AppState.swift`  ⟶ User session + routing
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
* [x] `TagBinding.swift`
* [x] `TagHistory.swift`
* [x] `Customer.swift`
* [ ] `AuditLog.swift` (core model; required)
* [x] `WorkOrdersDatabase.swift`
* [x] `CustomerDatabase.swift`
* [x] `DropdownManager.swift`
* [x] `TagManager.swift`     // manages tag bindings (bind/unbind/reassign); writes TagHistory; updates /tagIndex
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
* [ ] `WO_ItemTagListView.swift`    // chips UI for QR bindings (Primary/Aux • Position Label • Set Primary • Edit • Unbind)
* [ ] `NotesTimelineView.swift`
* [ ] `StatusBadge.swift`
* [ ] `WorkOrderNumberBadge.swift`

---

## 🔐 Phase 5: Role & Admin Tools

* [ ] `SettingsView.swift`
* [ ] `DropdownManagerView.swift`
* [ ] `UserManagerView.swift`
* [ ] `DeletedWorkOrdersView.swift`
* [ ] `SyncStatusView.swift`
* [ ] `PendingApprovalView.swift`
* [ ] `ManagerReviewView.swift`
* [ ] `ClosedWorkOrdersView.swift`
* [ ] `AuditLogView.swift` (UI; role-gated Admin/Manager)
* [ ] `SidebarDrawerView.swift` (compact sidebar)
* [ ] `NavBarHamburgerButton.swift` (compact only)
* [ ] `NavBarOverflowButton.swift` (ellipsis actions)
* [ ] `NavBarSettingsButton.swift` (gear, wide only)

---

## 🧪 Phase 6: Finalization & QA

* [ ] TestCases.md
* [ ] Developer Checklist ✅
* [ ] Firebase sync & retry logic
* [ ] Offline queue testing
* [ ] Tag search resolves via **active bindings + tagHistory** (dedupes to the current WO_Item owner; shows “matched via history” hint when applicable)
* [ ] Sample data loader
* [ ] `EmojiPickerView.swift`
* [ ] `CustomersCSVImport` (wizard surfaced in `CustomersView`)

---

## 🧩 Optional Enhancements

* [ ] Dark mode support
* [ ] Tablet-specific UI refinements
* [ ] Archive mode (read-only WorkOrders)
* [ ] Sync log viewer
