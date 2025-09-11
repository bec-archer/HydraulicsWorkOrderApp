# 🧭 Navigation Flow – Hydraulics Work Order App

---

## 🔐 Login → Role-Based Routing

```
LoginView
├── Valid PIN (Tech)     → ActiveWorkOrdersView
├── Valid PIN (Manager)  → ActiveWorkOrdersView + Sidebar
├── Valid PIN (Admin)    → Full Sidebar + SettingsView
├── Valid PIN (SuperAdmin) → Full Access + Dev Tools
```

---

## 🏠 Main App Flow (Tech)

```
ActiveWorkOrdersView
├── + New → NewWorkOrderView
│    ├── Customer Lookup
│    ├── + Add New Customer Modal
│    ├── Add 1+ WO_Items
│    │    ├── QR Codes: **Add QR** (multiple) → Primary/Aux, optional Position Label
│    │    └── If scanned tag is active on another item → **Tag Reassignment** prompt
│    └── Check In
├── Tap WorkOrder → WorkOrderDetailView
│    ├── Tap WO_Item → WorkOrderItemDetailView
│    │    └── QR Codes section (chips • Set Primary • Edit Label • Unbind)
│    └── NotesTimelineView
└── Search → SearchView (resolves **active bindings** + **tagHistory**; dedupes to the current owner when matched via history)

---

## 🧭 Global Scanner

Scanner
├── Tag is **active** on this WO_Item → open WorkOrderItemDetailView (update last seen)
├── Tag is **active** on another item → prompt **Tag Reassignment** (on confirm: old binding deactivates, new binding added here; `tagHistory(event:"reassigned")` appended)
└── Tag **unbound/inactive** → **Bind** to current context (defaults to Aux unless no Primary exists)

---

## ⚙️ Admin / Manager Sidebar Routes

Sidebar (Admin)
├── ActiveWorkOrdersView
├── CompletedWorkOrdersView
├── ClosedWorkOrdersView
├── CustomersView
├── DeletedWorkOrdersView
├── DropdownManagerView
├── UserManagerView
├── AuditLogView
├── SettingsView
└── SyncStatusView

Sidebar (Manager)
├── ActiveWorkOrdersView
├── PendingApprovalView
├── ManagerReviewView

---

## 🔄 Dev Toggles / Access (Super Admin Only)

SettingsView
├── Toggle Login Screen
├── Toggle Tag Scan Enforcement
├── Reload Sample Data
└── Monitor Sync Queue


---

## 🔁 WorkOrder Lifecycle

New ➝ Checked In ➝ In Progress ➝ Done ➝ Tested ➝ Completed ➝ Closed
						↳ FAIL ➝ PROBLEM CHILD

Each status emits a WO_Status entry and appears in NotesTimelineView
