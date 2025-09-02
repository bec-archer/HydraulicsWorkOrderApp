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
│    └── Add 1+ WO_Items → Check In
├── Tap WorkOrder → WorkOrderDetailView
│    ├── Tap WO_Item → WorkOrderItemDetailView
│    └── NotesTimelineView
└── Search → SearchView
```

---

## ⚙️ Admin / Manager Sidebar Routes

```
Sidebar (Admin)
├── ActiveWorkOrdersView
├── CompletedWorkOrdersView
├── CustomersView
├── DeletedWorkOrdersView
├── DropdownManagerView (includes Reasons for Service)
├── UserManagerView
├── SettingsView
└── SyncStatusView

Sidebar (Manager)
├── ActiveWorkOrdersView
├── PendingApprovalView
├── ManagerReviewView
└── DropdownManagerView (read-only, Request Change)
```

---

## 🔄 Dev Toggles / Access (Super Admin Only)

```
SettingsView
├── Toggle Login Screen
├── Toggle Tag Scan Enforcement
├── Reload Sample Data
└── Monitor Sync Queue
```

---

## 🔁 WorkOrder Lifecycle

```
New ➝ Checked In ➝ In Progress ➝ Done ➝ Tested ➝ Completed ➝ Closed
                        ↳ FAIL ➝ PROBLEM CHILD
```

Each status emits a WO\_Status entry and appears in NotesTimelineView
