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
* `WO_Item.tags` (array of TagBinding for multiple QR codes)
* `WO_Item.tagHistory` (audit of bind / unbind / reassign events)

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
* Card thumbnails: show **up to 4 images** — the **first image** from up to four WO_Items (item create order)
* Tech can scan one or more QR codes per WO_Item:
  * First tag defaults to **Primary**; subsequent scans default to **Auxiliary**
  * Optional **Position Label** prompt (e.g., A/B/C, Rod/Cap, Left/Right) for reassembly guidance
  * If a scanned tag is already active on another item → app prompts for **Reassign**
* Dropdown schema version frozen

---

## 👨‍💼 Workflow 2: Manager Approval (PROBLEM CHILD)

### 1) Trigger & Entry

* **User action:** Tech logs second **FAIL** on WO_Item
* **Start view:** `ActiveWorkOrdersView.swift` → flagged card

### 2) Views & Components

* `PendingApprovalView.swift` shows flagged/problematics
* `ManagerReviewView.swift` opens detailed review

  * Inline: `WorkOrderItemDetailView.swift` for item specifics
  * `NotesTimelineView.swift` for audit trail

### 3) Models

* `WO_Status.swift` (FAIL history)
* `WO_Item.swift` (flagged)
* `WO_Item.tagHistory` (bind/unbind/reassign audit for QR codes)
* `WorkOrder.swift` container

### 4) Managers & Helpers

* `WorkOrdersDatabase.swift` (fetch flagged)
* `SyncManager.swift` (ensures fail flags sync)

### 5) Data Stores

* Firestore: WO_Item with `statusHistory` + `testResult`
* SQLite: mirrors fail history for offline

### 6) Navigation Flow

`ActiveWorkOrdersView` → `PendingApprovalView` → tap flagged WO → `ManagerReviewView` → resolve/override

### 7) Notifications / Side Effects

* On 2nd FAIL: card flagged **PROBLEM CHILD**
* Push alert sent to managers
* Resolution recorded in status log
* Managers/Admins may also review and approve/deny **tag reassignments**:
  * If a scanned QR code is active on another item, the app records a `tagHistory` event (pending reassign).
  * **Approval:** append `tagHistory(event:"reassigned")`, deactivate the old binding, and activate the new binding.
  * **Denial:** append `tagHistory(event:"unbound")` for the attempted tag (no new binding created).

---

## ✅ Workflow 3: Closing a Work Order

### 1) Trigger & Entry

* **User action:** After pickup/payment, tech/manager/admin taps **Mark Closed**
* **Start view:** `WorkOrderDetailView.swift`

### 2) Views & Components

* `WorkOrderDetailView.swift`

  * Shows WO_Items, NotesTimelineView
  * Action button: Mark Closed
* Status badge updates to Closed

### 3) Models

* `WorkOrder.swift` (roll-up flags updated: `isClosed: Bool`, `closedAt: Date?`)* `WO_Status.swift` (new status entry)

### 4) Managers & Helpers

* `WorkOrdersDatabase.swift` (update status)
* `SyncManager.swift` (syncs to Firestore)
* `LocalBackupManager.swift` (SQLite mirror)

### 5) Data Stores

* Firestore: WorkOrder roll-ups → `isClosed = true`, `closedAt = <timestamp>`
* SQLite: updated status synced

### 6) Navigation Flow

`ActiveWorkOrdersView` → `WorkOrderDetailView` → tap **Mark Closed** → WorkOrder disappears from active list → moves to manager-only closed access

### 7) Notifications / Side Effects

* Card hidden from Active list
* Closed WOs only visible in Manager/Admin sidebar views
* Audit entry logged in NotesTimelineView
* Indicator dots added to the card:
  * **Overlay** dots on top-right of each item thumbnail (one per WO_Item)
  * **Inline** dots on the same line as the **WO_Number**
* Tag search resolves current **and previous** tag IDs (via tag history)

---

📌 **Note:** No `WorkOrderAccordionView` exists in the final structure. Inline item entry is handled by `NewWorkOrderView` + `DropdownField` + `PhotoPickerView`.
