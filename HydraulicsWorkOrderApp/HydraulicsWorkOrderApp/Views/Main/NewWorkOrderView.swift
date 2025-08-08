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

struct NewWorkOrderView: View {
    @State private var searchText = ""
    @State private var selectedCustomer: Customer? = nil
    @State private var showAddCustomerModal = false

    @ObservedObject var customerDB = CustomerDatabase.shared
    
    @State private var flagged = false
    @State private var items: [WO_Item] = [WO_Item.sample]

    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                // ───── Customer Lookup Section ────
                Section(header: Text("Customer Lookup")) {
                    if let customer = selectedCustomer {
                        // ───── Selected Customer Card ─────
                        HStack {
                            VStack(alignment: .leading) {
                                Text(customer.name)
                                    .font(.headline)
                                Text(customer.phone)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                selectedCustomer = nil
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        // ───── Search Field ─────
                        TextField("Enter name or phone number", text: $searchText)
                            .onChange(of: searchText) {
                                customerDB.fetchCustomers()
                            }

                        // ───── Search Results ─────
                        let matches = customerDB.searchCustomers(matching: searchText)

                        if !searchText.isEmpty {
                            if matches.isEmpty {
                                Button(action: {
                                    showAddCustomerModal = true
                                }) {
                                    Label("Add New Customer", systemImage: "plus.circle")
                                }
                            } else {
                                ForEach(matches) { customer in
                                    Button {
                                        selectedCustomer = customer
                                        searchText = ""
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(customer.name)
                                                    .fontWeight(.medium)
                                                Text(customer.phone)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                    }
                }
                // ───── End Add Customer Modal    ─────
                
                // ───── Work Order Details Section ─────

                Section(header: Text("Work Order Details")) {
                    Toggle("Flag for Attention", isOn: $flagged)
                }

                ForEach($items) { $item in
                    AddWOItemFormView(item: $item)
                }

                Section {
                    Button("+ Add Item") {
                        items.append(WO_Item.sample)
                    }
                }

                Section {
                    Button("✅ Save Work Order") {
                        saveWorkOrder()
                    }
                }
            }
            .navigationTitle("New Work Order")
            .alert("Status", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showAddCustomerModal) {
                // Determine which field was typed
                let isPhone = CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: searchText))
                let namePrefill = isPhone ? "" : searchText
                let phonePrefill = isPhone ? searchText : ""

                NewCustomerModalView(
                    prefillName: namePrefill,
                    prefillPhone: phonePrefill,
                    selectedCustomer: $selectedCustomer
                )
            }
            // END .Form
        }
        // END .body
    }

    // ───── Firestore Save Handler ─────
    func saveWorkOrder() {
        // Validate inputs
        // Ensure a customer is selected
        guard let customer = selectedCustomer else {
            alertMessage = "Please select a customer."
            showAlert = true
            return
        }
        // Validate phone number
        guard !items.isEmpty else {
            alertMessage = "Please add at least one piece of equipment."
            showAlert = true
            return
        }
        // Validate phone number format
        let newWO = WorkOrder(
            id: nil, // Firestore will auto-generate this
            createdBy: "DevUser", // Hardcoded for now, replace with actual user ⚠️
            phoneNumber: customer.phone, // Use the customer's phone number
            WO_Type: "Auto", // auto-tagged inside WO_Items now
            imageURL: nil, //  No image upload in this view ⚠️
            timestamp: Date(), // Initial check-in time
            status: "Checked In", // Default status
            WO_Number: generateWorkOrderNumber(), // Generate unique number
            flagged: flagged, // Flag for follow-up
            tagId: nil, // No tag ID in this view
            estimatedCost: nil, // No cost estimate in this view
            finalCost: nil, // No final cost in this view
            dropdowns: [:], // No dropdowns in this view
            dropdownSchemaVersion: 1, // Default schema version
            lastModified: Date(), // Current timestamp
            lastModifiedBy: "DevUser", // Hardcoded for now, replace with actual user ⚠️
            tagBypassReason: nil, // No tag bypass reason in this view
            isDeleted: false, // Not deleted
            notes: [], // No notes in this view
            items: items // Use the items array from the view
        )
            // Save to Firestore
        // Use the shared database instance
        WorkOrdersDatabase.shared.addWorkOrder(newWO) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    alertMessage = "✅ Work Order saved!"
                    searchText = ""
                    selectedCustomer = nil
                    flagged = false
                    items = [WO_Item.sample]
                case .failure(let error):
                    alertMessage = "❌ Failed to save: \(error.localizedDescription)"
                }
                showAlert = true
            }
        }
    }
    // END .saveWorkOrder
    // ───── Generate Work Order Number ─────
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
