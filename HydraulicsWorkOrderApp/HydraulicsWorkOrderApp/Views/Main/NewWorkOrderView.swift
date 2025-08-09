//
//  NewWorkOrderView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 NewWorkOrderView.swift
// Customer lookup + inline WO_Item forms, with NewCustomerModal sheet
// ─────────────────────────────────────────────────────────────

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct NewWorkOrderView: View {
    // ───── STATE ─────
    @State private var selectedCustomer: Customer?
    @State private var searchText: String = ""
    @State private var matchingCustomers: [Customer] = []
    @State private var flagged: Bool = false
    @State private var items: [WO_Item] = [WO_Item.sample]
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showingNewCustomerModal: Bool = false   // ✅ fixed: had no Bool type
    
    // ───── Prefill Helpers (derive from searchText) ─────
    private var prefillNameFromSearch: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        return digits.count >= 3 ? "" : trimmed   // numbers ⇒ phone, else ⇒ name
    }
    private var prefillPhoneFromSearch: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        return digits.count >= 3 ? trimmed : ""   // digits ⇒ phone, else blank
    }
    // END Prefill Helpers
    
    // ───── BODY ─────
    var body: some View {
        NavigationStack {
            Form {
                // ───── CUSTOMER LOOKUP ─────
                Section(header: Text("Customer Lookup")) {
                    if let customer = selectedCustomer {
                        // Selected customer summary card
                        VStack(alignment: .leading, spacing: 4) {
                            Text(customer.name).font(.headline)
                            Text(customer.phone).font(.subheadline)
                            
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
                        // Search + results + Add New button
                        VStack(alignment: .leading) {
                            TextField("Search by name or phone", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                            
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
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            } else if !searchText.isEmpty {
                                Button {
                                    showingNewCustomerModal = true
                                } label: {
                                    Label("Add New Customer", systemImage: "plus.circle")
                                        .foregroundStyle(.blue)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                // END Customer Lookup
                
                // ───── WORK ORDER FLAGS ─────
                Section(header: Text("Work Order Info")) {
                    Toggle("Flag this WorkOrder", isOn: $flagged)
                }
                // END Work Order Flags
                
                // ───── WO_Item ENTRY ─────
                Section(header: Text("Equipment Items")) {
                    ForEach($items) { $item in
                        VStack {
                            AddWOItemFormView(item: $item)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .padding(.vertical, 6)
                    }
                    
                    Button {
                        items.append(WO_Item.sample)
                    } label: {
                        Label("Add Another Item", systemImage: "plus.circle")
                    }
                }
                // END WO_Item Entry
                
                // ───── SAVE ─────
                Section {
                    Button("✅ Save Work Order") {
                        saveWorkOrder()
                    }
                }
                // END Save
            }
            .navigationTitle("New Work Order")
            .alert(Text("Status"), isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            // ───── SAFE ONCHANGE FOR iOS 16+17 ─────
            .onChange(of: searchText) {
                handleSearchTextChange(searchText)
            }
            // END onChange
        } // END NavigationStack
        // ───── New Customer Modal Sheet (attached to NavigationStack) ─────
        .sheet(isPresented: $showingNewCustomerModal) {
            NewCustomerModalView(
                prefillName: prefillNameFromSearch,
                prefillPhone: prefillPhoneFromSearch,
                selectedCustomer: $selectedCustomer
            )
        }
        // END sheet
    }
    // END .body
    
    // ───── SEARCH HANDLER ─────
    private func handleSearchTextChange(_ newValue: String) {
        if newValue.isEmpty {
            matchingCustomers = []
            return
        }
        
        let lower = newValue.lowercased()
        Firestore.firestore().collection("customers").getDocuments { snapshot, _ in
            if let docs = snapshot?.documents {
                let all = docs.compactMap { try? $0.data(as: Customer.self) }
                matchingCustomers = all.filter {
                    $0.name.lowercased().contains(lower) || $0.phone.contains(lower)
                }
            }
        }
    }
    // END Search Handler
    
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
    // END Save Handler
}
// END struct

// ───── PREVIEW ─────
#Preview {
    NewWorkOrderView()
}
// END Preview
