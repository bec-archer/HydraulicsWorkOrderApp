# 📁 Hydraulics Work Order App – File Structure - Actual Build

* Existing Files/Folders are marked with ✅
* New Files not originally in File Structure are marked with 🧩
* Scaffolded Files marked with 🏗️

---

## 🧠 App Root

```
HydraulicsWorkOrderApp/✅
├── App/ ✅
│   ├── AppDelegate.swift ✅                 # Lifecycle management
│   ├── AppState.swift                     # Global user state		
├──HydraulicsWorkOrderAppApp.swift ✅  	 # App entry point
├──FirestoreTestView.swift 🧩✅         # Used to test Firebase connection
└──ContentView.swift 🧩✅
```

---

## 🧾 Models

```
├── Models/✅
│   ├── Core/✅
│   │   ├── WorkOrder.swift ✅          # One per customer visit
│   │   ├── WO_Item.swift ✅          # One per equipment item
│   │   ├── WO_Status.swift 🏗️          # Tracks all status updates
│   │   ├── WO_Note.swift ✅            # Freeform notes
│   │   ├── Customer.swift ✅
│   │   ├── User.swift
│   │   ├── AuditLog.swift           # Tag reassignments, deletions, etc.
│   │   └── TagReplacement.swift 🧩🏗️ 
│   │
│   ├── Enums/✅
│   │   ├── UserRole.swift ✅           # tech, manager, admin, superadmin
│   │   ├── TagBypassReason.swift
│   │   ├── TestResult.swift
│   │   ├── NoteType.swift
│   │   └── WO_Type.swift
```

---

## 📲 Views

```
├── Views/✅
│   ├── Main/
│   │   ├── ActiveWorkOrdersView.swift ✅     # Replaces ActiveWO_sView
│   │   ├── CompletedWorkOrdersView.swift  # Replaces CompletedWO_sView
│   │   ├── NewWorkOrderView.swift ✅         # Replaces NewWO_View
│   │   ├── WorkOrderDetailView.swift      # Replaces WO_DetailView
│   │   ├── WorkOrderItemDetailView.swift  # Replaces WO_ItemDetailView
│   │   ├── SearchView.swift
│   │   ├── AddWOItemView.swift 🧩✅
│   │   ├── AddWOItemFormView.swift 🧩✅	# Inline Form for Entry
│   │   ├── NewCustomerModalView.swift 🧩✅
│   │   └── AddWOItemView.swift 🧩✅
│   │
│   ├── Components/
│   │   ├── WorkOrderCardView.swift ✅        # Replaces WO_CardView
│   │   ├── DropdownField.swift ✅ 
│   │   ├── PhotoPickerView.swift
│   │   ├── NotesTimelineView.swift
│   │   └── StatusBadge.swift✅ 
│   │
│   ├── Authentication/✅
│   │   ├── LoginView.swift✅
│   │   └── UserSelectionView.swift
│   │
│   ├── Manager/
│   │   ├── PendingApprovalView.swift
│   │   └── ManagerReviewView.swift
│   │
│   ├── Admin/
│   │   ├── SettingsView.swift
│   │   ├── UserManagerView.swift
│   │   ├── DropdownManager.swift ⚠️ saved in /Managers/Data
│   │   ├── DeletedWorkOrdersView.swift    # Replaces DeletedWO_sView
│   │   └── SyncStatusView.swift
```

---

## 🔧 Managers

```
├── Managers/✅
│   ├── Data/
│   │   ├── WorkOrdersDatabase.swift✅
│   │   ├── CustomerDatabase.swift ✅
│   │   ├── LocalBackupManager.swift       # Writes SQLite copy
│   │   ├── SyncManager.swift              # Firebase sync + retry, conflict resolution
│   │   └── DropdownManagerView.swift 
│   │
│   ├── Configuration/✅
│   │   ├── SettingsManager.swift
│   │   ├── DevSettingsManager.swift ✅
│   │   └── DropdownManager.swift    # Stays here for now (handles constants)
```

---

## 🛠 Utilities

```
├── Utilities/
│   ├── Extensions/
│   │   ├── Date+Extensions.swift
│   │   ├── View+Extensions.swift
│   │   └── String+Extensions.swift
│   │
│   ├── Helpers/
│   │   └── WorkOrderNumberGenerator.swift # Replaces WO_NumberGenerator.swift
│   │
│   └── Constants/ ✅
│       ├── AppConstants.swift
│       ├── UIConstants.swift
│       ├── ErrorMessages.swift
│       └── DropdownSchema.swift 🧩✅
```

---

## 📦 Resources

```
├── Resources/ ✅
│   ├── Assets.xcassets/
│   ├── AppleNotesYellow.json              # Theme config
│   ├── GoogleService-Info.plist ✅           # Firebase
│   └── Database.plist                     # SQLite backup config
```

---

## 🧪 Tests

```
├── Tests/
│   ├── UnitTests/
│   ├── UITests/
│   └── IntegrationTests/
```
