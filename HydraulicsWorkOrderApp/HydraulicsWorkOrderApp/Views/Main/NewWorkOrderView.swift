//
//  NewWorkOrderView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 NewWorkOrderView.swift
// Updated to show inline WO_Item forms, no modals
// ─────────────────────────────────────────────────────────────

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct NewWorkOrderView: View {
    @State private var selectedCustomer: Customer?
    @State private var searchText = ""
    @State private var matchingCustomers: [Customer] = []
    @State private var flagged = false
    @State private var items: [WO_Item] = [WO_Item.sample]
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingNewCustomerModal = false

    var body: some View {
        NavigationStack {
            Form {
                // ───── CUSTOMER LOOKUP ─────
                Section(header: Text("Customer Lookup")) {
                    if let customer = selectedCustomer {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(customer.name)
                                .font(.headline)
                            Text(customer.phone)
                                .font(.subheadline)
                            Button {
                                selectedCustomer = nil
                                searchText = ""
                            } label: {
                                Label("Clear", systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 6)
                        }
                    } else {
                        VStack(alignment: .leading) {
                            TextField("Search by name or phone", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            if !matchingCustomers.isEmpty {
                                ForEach(matchingCustomers, id: \.id) { customer in
                                    Button {
                                        selectedCustomer = customer
                                        searchText = ""
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(customer.name)
                                            Text(customer.phone)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            } else if !searchText.isEmpty {
                                Button {
                                    showingNewCustomerModal = true
                                } label: {
                                    Label("Add New Customer", systemImage: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }

                // ───── WORK ORDER FLAGS ─────
                Section(header: Text("Work Order Info")) {
                    Toggle("Flag this Work Order", isOn: $flagged)
                }

                // ───── WO_Item ENTRY ─────
                Section(header: Text("Equipment Items")) {
                    ForEach($items.indices, id: \.self) { index in
                        AddWOItemFormView(item: $items[index])
                    }

                    Button(action: {
                        items.append(WO_Item.sample)
                    }) {
                        Label("Add Another Item", systemImage: "plus.circle")
                    }
                }

                // ───── SAVE ─────
                Section {
                    Button("✅ Save Work Order") {
                        saveWorkOrder()
                    }
                }
            }
            .navigationTitle("New Work Order")
            .alert(Text("Status"), isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onChange(of: searchText, perform: { newValue in
                if newValue.isEmpty {
                    matchingCustomers = []
                } else {
                    let lower = newValue.lowercased()
                    Firestore.firestore().collection("customers").getDocuments { snapshot, error in
                        if let docs = snapshot?.documents {
                            let all = docs.compactMap { try? $0.data(as: Customer.self) }
                            matchingCustomers = all.filter {
                                $0.name.lowercased().contains(lower) || $0.phone.contains(lower)
                            }
                        }
                    }
                }
            })

        }
    }

    // ───── SAVE HANDLER ─────
    func saveWorkOrder() {
        guard let customer = selectedCustomer else {
            alertMessage = "Please select a customer"
            showAlert = true
            return
        }

        let newWorkOrder = WorkOrder(
            id: UUID().uuidString,
            createdBy: "TestUser",
            customerId: customer.id ?? "unknown",
            customerName: customer.name,
            customerPhone: customer.phone,
            WO_Type: items.first?.dropdowns["type"] ?? "Unknown",
            imageURL: nil,
            timestamp: Date(),
            status: "CheckedIn",
            WO_Number: "080824-001",
            flagged: flagged,
            tagId: nil,
            estimatedCost: nil,
            finalCost: nil,
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            lastModified: Date(),
            lastModifiedBy: "TestUser",
            tagBypassReason: nil,
            isDeleted: false,
            notes: [],
            items: items
        )

        WorkOrdersDatabase.shared.addWorkOrder(newWorkOrder) { result in
            switch result {
            case .success:
                alertMessage = "✅ Work Order saved!"
                flagged = false
                items = [WO_Item.sample]
            case .failure(let error):
                alertMessage = "❌ Failed to save: \(error.localizedDescription)"
            }
            showAlert = true
        }
    }
}

// END
#Preview {
    NewWorkOrderView()
}
