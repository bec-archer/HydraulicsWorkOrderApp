//
//  NewWorkOrderView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 NewWorkOrderView.swift
// Create a new WorkOrder with at least one WO_Item
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct NewWorkOrderView: View {
    // ───── Top-Level WO Fields ─────
    @State private var phoneNumber = ""
    @State private var WO_Type = ""
    @State private var flagged = false

    // ───── Equipment Items ─────
    @State private var items: [WO_Item] = []
    @State private var showAddItemSheet = false

    // ───── Alert / Feedback ─────
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Customer Info")) {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                Section(header: Text("Work Order Details")) {
                    TextField("Type (e.g. Cylinder, Pump)", text: $WO_Type)
                    Toggle("Flag for Attention", isOn: $flagged)
                }

                Section(header: Text("Equipment Items")) {
                    if items.isEmpty {
                        Text("No equipment added yet.")
                    } else {
                        ForEach(items) { item in
                            Text("• \(item.type)")
                        }
                    }

                    Button("+ Add Equipment") {
                        showAddItemSheet = true
                    }
                }

                Section {
                    Button("✅ Save Work Order") {
                        saveWorkOrder()
                    }
                }
            }
            .navigationTitle("New Work Order")
            .sheet(isPresented: $showAddItemSheet) {
                AddWOItemView(items: $items)
            }
            .alert("Status", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        // END .body
    }

    // ───── Firestore Save Handler ─────
    func saveWorkOrder() {
        guard !phoneNumber.isEmpty, !WO_Type.isEmpty else {
            alertMessage = "Please complete all required fields."
            showAlert = true
            return
        }

        guard !items.isEmpty else {
            alertMessage = "Please add at least one piece of equipment."
            showAlert = true
            return
        }

        let newWO = WorkOrder(
            id: nil,
            createdBy: "DevUser", // Will link to logged in user later
            phoneNumber: phoneNumber,
            WO_Type: WO_Type,
            imageURL: nil,
            timestamp: Date(),
            status: "Checked In",
            WO_Number: generateWorkOrderNumber(),
            flagged: flagged,
            tagId: nil,
            estimatedCost: nil,
            finalCost: nil,
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            lastModified: Date(),
            lastModifiedBy: "DevUser",
            tagBypassReason: nil,
            isDeleted: false,
            notes: [],
            items: items
        )

        WorkOrdersDatabase.shared.addWorkOrder(newWO) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    alertMessage = "✅ Work Order saved!"
                    phoneNumber = ""
                    WO_Type = ""
                    flagged = false
                    items = []
                case .failure(let error):
                    alertMessage = "❌ Failed to save: \(error.localizedDescription)"
                }
                showAlert = true
            }
        }
    }

    // ───── Work Order Number Generator ─────
    func generateWorkOrderNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMddyy"
        let prefix = formatter.string(from: Date())
        let suffix = Int.random(in: 100...999)
        return "\(prefix)-\(suffix)"
    }

    // END
}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    NewWorkOrderView()
}
