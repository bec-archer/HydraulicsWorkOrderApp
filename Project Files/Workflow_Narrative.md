# 📑 Workflow Narratives – Hydraulics Work Order App

This document describes how different workflows map to files, views, models, and managers in the Hydraulics Work Order App.

---

## 🆕 Workflow 1: New Work Order (from ActiveWorkOrdersView)

### 1) Trigger & Entry

* **User action:** Tap **+ New Work Order**
* **Start view:** `ActiveWorkOrdersView.swift` (grid of active WOs)

### 2) Views & Components

* `NewWorkOrderView.swift` (intake form)

  * `CustomerDatabase.swift` lookup
  * `NewCustomerModalView.swift` (if no match)
  * Inline: `DropdownField.swift`, `PhotoPickerView.swift`
* Return to `ActiveWorkOrdersView.swift`
* New card rendered via `WorkOrderCardView.swift`

### 3) Models

* `WorkOrder.swift`, `WO_Item.swift`, `WO_Status.swift`, `WO_Note.swift`, `Customer.swift`

### 4) Managers & Helpers

* `CustomerDatabase.swift` (lookup/create)
* `WorkOrdersDatabase.swift` (save)
* `WorkOrderNumberGenerator.swift` (YYMMDD-###)
* `SyncManager.swift` (Firebase sync)
* `LocalBackupManager.swift` (SQLite backup)

### 5) Data Stores

* Firestore: `/workOrders/{id}` + `/items/{itemId}`
* Firebase Storage: image uploads
* SQLite: mirrors for offline

### 6) Navigation Flow

`ActiveWorkOrdersView` → `NewWorkOrderView` → *(optional)* `NewCustomerModalView` → Save/Check In → back to `ActiveWorkOrdersView` (new card appears)

### 7) Notifications / Side Effects

* Status auto-marked **Checked In**
* First image = card thumbnail
* Dropdown schema version frozen

---

## 👨‍💼 Workflow 2: Manager Approval (PROBLEM CHILD)

### 1) Trigger & Entry

* **User action:** Tech logs second **FAIL** on WO\_Item
* **Start view:** `ActiveWorkOrdersView.swift` → flagged card

### 2) Views & Components

* `PendingApprovalView.swift` shows flagged/problematics
* `ManagerReviewView.swift` opens detailed review

  * Inline: `WorkOrderItemDetailView.swift` for item specifics
  * `NotesTimelineView.swift` for audit trail

### 3) Models

* `WO_Status.swift` (FAIL history)
* `WO_Item.swift` (flagged)
* `TagReplacement.swift` (if tag reassigned)
* `WorkOrder.swift` container

### 4) Managers & Helpers

* `WorkOrdersDatabase.swift` (fetch flagged)
* `SyncManager.swift` (ensures fail flags sync)

### 5) Data Stores

* Firestore: WO\_Item with `statusHistory` + `testResult`
* SQLite: mirrors fail history for offline

### 6) Navigation Flow

`ActiveWorkOrdersView` → `PendingApprovalView` → tap flagged WO → `ManagerReviewView` → resolve/override

### 7) Notifications / Side Effects

* On 2nd FAIL: card flagged **PROBLEM CHILD**
* Push alert sent to managers
* Resolution recorded in status log

---

## ✅ Workflow 3: Closing a Work Order

### 1) Trigger & Entry

* **User action:** After pickup/payment, tech/manager/admin taps **Mark Closed**
* **Start view:** `WorkOrderDetailView.swift`

### 2) Views & Components

* `WorkOrderDetailView.swift`

  * Shows WO\_Items, NotesTimelineView
  * Action button: Mark Closed
* Status badge updates to Closed

### 3) Models

* `WorkOrder.swift` (status field updated)
* `WO_Status.swift` (new status entry)

### 4) Managers & Helpers

* `WorkOrdersDatabase.swift` (update status)
* `SyncManager.swift` (syncs to Firestore)
* `LocalBackupManager.swift` (SQLite mirror)

### 5) Data Stores

* Firestore: WorkOrder status → `Closed`
* SQLite: updated status synced

### 6) Navigation Flow

`ActiveWorkOrdersView` → `WorkOrderDetailView` → tap **Mark Closed** → WorkOrder disappears from active list → moves to manager-only closed access

### 7) Notifications / Side Effects

* Card hidden from Active list
* Closed WOs only visible in Manager/Admin sidebar views
* Audit entry logged in NotesTimelineView

---

📌 **Note:** No `WorkOrderAccordionView` exists in the final structure. Inline item entry is handled by `NewWorkOrderView` + `DropdownField` + `PhotoPickerView`.
