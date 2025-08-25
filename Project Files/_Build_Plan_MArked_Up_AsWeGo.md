# 📦 Build Plan – Hydraulics Work Order App

*Prioritized file creation and milestone tracking*
* Completed tasks marked with ✅
* Scaffolded Files marked with 🏗️
---

## 🧱 Phase 1: Core Setup

* [x] `AppState.swift`  ⟶ User session + routing ✅
* [x] `HydraulicsCheckInAppApp.swift`✅
* [x] `LoginView.swift` + PIN handling
* [x] `User.swift` model + role enum
* [x] `UserManager.swift` basic storage

---

## 🧾 Phase 2: WorkOrder Models & Storage

* [x] `WorkOrder.swift`✅

* [x] `WO_Item.swift`✅

* [x] `WO_Status.swift`🏗️

* [x] `WO_Note.swift`🏗️

* [x] `TagReplacement.swift`🏗️

* [x] `Customer.swift`
struct AddWOItemFormView: View {
	@Binding var item: WO_Item
	@State private var customColor = Color.yellow
	@State private var reasonNotes = ""
	
	let dropdowns = DropdownManager.shared
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			// Your existing form content
			// ...
		}
		// Color handling
		.onChange(of: item.dropdowns["color"]) { newValue in
			let value = (newValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
			if value.isEmpty {
				item.dropdowns["colorHex"] = ""
				return
			}
			
			if let chosen = (dropdowns.options["color"] ?? []).first(where: { $0.value == value }),
			   let hex = chosen.colorHex, !hex.isEmpty {
				item.dropdowns["colorHex"] = hex
			} else if value.caseInsensitiveCompare("Other") == .orderedSame {
				// For "Other", use the current customColor
				updateColorHexFromCustomColor()
			} else {
				item.dropdowns["colorHex"] = ""
			}
		}
		.onChange(of: customColor) { newColor in
			let isOther = (item.dropdowns["color"] ?? "").caseInsensitiveCompare("Other") == .orderedSame
			guard isOther else { return }
			updateColorHexFromCustomColor()
		}
		.onAppear {
			// Initialize reasonNotes with the value from item
			reasonNotes = item.reasonNotes
			
			// Initialize customColor if colorHex is available
			if let hexColor = item.dropdowns["colorHex"], !hexColor.isEmpty {
				customColor = Color(hex: hexColor) ?? .yellow
			}
		}
		.padding(12)
	}
	
	// Helper function to update color hex
	private func updateColorHexFromCustomColor() {
		if let comps = UIColor(customColor).cgColor.components, comps.count >= 3 {
			let r = Int(round(comps[0] * 255))
			let g = Int(round(comps[1] * 255))
			let b = Int(round(comps[2] * 255))
			item.dropdowns["colorHex"] = String(format: "#%02X%02X%02X", r, g, b)
		}
	}
}
* [ ] `AuditLog.swift`

* [x] `WorkOrdersDatabase.swift`✅

* [x] `CustomerDatabase.swift`

* [x] `DropdownManager.swift`

---

## 🧪 Phase 3: WorkOrder Intake UI

* [x] `ActiveWorkOrdersView.swift`✅

* [x] `NewWorkOrderView.swift`✅

* [x] `WorkOrderCardView.swift`✅

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
* [ ] `StatusBadge.swift`✅

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
* [ ] Developer Checklist 
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
