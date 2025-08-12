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
    @State private var items: [WO_Item] = [WO_Item.blank()]
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var expandedIndex: Int? = nil
    @State private var showingNewCustomerModal: Bool = false   // ✅ fixed: had no Bool type
    @State private var isPickingCustomer = false
    @State private var searchDebounce: DispatchWorkItem?
    @State private var showSaveBanner: Bool = false
    @State private var savedWONumber: String = ""
    @ObservedObject private var customerDB = CustomerDatabase.shared
    
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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    // END Prefill Helpers


    // ───── BODY ─────
    var body: some View {
        NavigationStack {
            Form {
                // ───── CUSTOMER LOOKUP ─────
                Section(header: Text("Customer Lookup")) {
                    // CANCEL BUTTON INLINE
                    if let customer = selectedCustomer {
                        // Selected customer summary card with inline Clear button (compact layout)
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) { // ↓ tighter vertical spacing
                                Text(customer.name)
                                    .font(.headline)
                                Text(customer.phone)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                selectedCustomer = nil
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .imageScale(.large)
                                    .padding(.leading, 4)
                                    .accessibilityLabel("Clear selected customer")
                            }
                        }
                        .padding(.vertical, 4)
                        // END CANCEL BUTTON INLINE
                    } else {
                        // Search + results + Add New button
                        VStack(alignment: .leading) {
                            
                            // ----- CUSTOMER LOOKUP (INSIDE THE SECTION) -----
                            TextField("Search by name or phone", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isPickingCustomer) // ← prevent live search while selecting

                            if !matchingCustomers.isEmpty {
                                ForEach(matchingCustomers.indices, id: \.self) { idx in
                                    let customer = matchingCustomers[idx]
                                    Button {
                                        // Freeze updates during selection
                                        isPickingCustomer = true

                                        // Commit selection deterministically
                                        selectCustomer(customer)

                                        // Clear list immediately so no diffing can fire
                                        matchingCustomers = []
                                        searchText = ""

                                        // Unfreeze on next runloop
                                        DispatchQueue.main.async { isPickingCustomer = false }

                                        // (Optional) debug
                                        print("👆 PICKED (idx \(idx)):", customer.id.uuidString, customer.name, customer.phone)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(customer.name)
                                            Text(customer.phone)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                        .contentShape(Rectangle()) // nice big tap target
                                    }
                                    .buttonStyle(.plain)
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
//  --------- END HERE ---------------
                            // END VALIDATE ME??
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)) // ↓ tighter bottom spacing

                // END Customer Lookup
                
                // ───── WORK ORDER FLAGS ─────
                Section(header: Text("Work Order Info")) {
                    Toggle("Flag this WorkOrder", isOn: $flagged)
                }
                // END Work Order Flags
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)) // ↓ tighter top spacing
                
                // ───── WO_Item ENTRY ─────
                Section(header: Text("Equipment Items")) {
                    ForEach(items.indices, id: \.self) { idx in
                        WOItemAccordionRow(
                            index: idx,
                            items: $items,
                            expandedIndex: $expandedIndex,
                            onDelete: handleDeleteWOItem
                        )
                    }


                    Button {
                        // ───── Add & Expand New Item (atomic animation) ─────
                        withAnimation { // use default animation for iOS 16/17 safety
                            let insertIndex = items.count
                            let newItem = WO_Item.blank()
                            expandedIndex = nil            // collapse current
                            items.append(newItem)          // append new
                            expandedIndex = insertIndex    // expand the new one
                        }
                        // ───── END Add & Expand New Item ─────

                    } label: {
                        Label("Add Another Item", systemImage: "plus.circle")
                    }

                }

                // END WO_Item Entry
                
                // ───── SAVE ─────
                Section {
                    Button("✅ Save Work Order") {
                        saveWorkOrder {
                            AppState.shared.currentView = .activeWorkOrders  // ⬅️ Navigate to Active
                        }
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
            // ───── Debounced onChange (prevents list swapping mid‑tap) ─────
            .onChange(of: searchText) { _, newValue in
                print("🔁 onChange: searchText updated to '\(newValue)'")
                guard !isPickingCustomer else { return }
                searchDebounce?.cancel()
                let task = DispatchWorkItem { handleSearchTextChange(newValue) }
                searchDebounce = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: task)
            }
            // END Debounced onChange
            
            // ───── DIAGNOSTIC: Who is overwriting selectedCustomer? ─────
            .onChange(of: selectedCustomer) { _, newValue in
                guard let c = newValue else { return }
                print("⚠️ selectedCustomer CHANGED:", c.id.uuidString, c.name, c.phone)

                // Prevent triggering another change if already empty
                if !searchText.isEmpty {
                    print("🧹 Clearing searchText")
                    searchText = ""
                }

                if !matchingCustomers.isEmpty {
                    print("🧹 Clearing matchingCustomers")
                    matchingCustomers = []
                }
            }


            // END Diagnostic
            
            // ───── CUSTOMER INJECTION ─────

            // 🔁 Customer injected from NewCustomerModalView
            .onChange(of: selectedCustomer) { _, newValue in
                guard let c = newValue else { return }
                print("⚠️ selectedCustomer CHANGED:", c.id.uuidString, c.name, c.phone)

                // Prevent triggering another change if already empty
                if !searchText.isEmpty {
                    print("🧹 Clearing searchText")
                    searchText = ""
                }

                if !matchingCustomers.isEmpty {
                    print("🧹 Clearing matchingCustomers")
                    matchingCustomers = []
                }
            }



            .onAppear {
                // Prefetch customers once for fast local filtering
                customerDB.fetchCustomers()

                if expandedIndex == nil {
                    expandedIndex = items.indices.first
                }
            }


            // END onChange
            // ───── Toast Banner Overlay ─────
            .overlay(
                Group {
                    if showSaveBanner {
                        VStack {
                            Spacer()
                            Text("✅ WO-\(savedWONumber) Saved!")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.95))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                                .padding(.bottom, 30)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.3), value: showSaveBanner)
                        }
                    }
                }
            )
            // END overlay

            // ───── New Customer Modal Sheet (attached to NavigationStack) ─────
            .sheet(isPresented: $showingNewCustomerModal) {
                NewCustomerModalView(
                    prefillName: prefillNameFromSearch,
                    prefillPhone: prefillPhoneFromSearch,
                    selectedCustomer: $selectedCustomer
                )
            }
            // END sheet
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
    
    
    
    // ───── SEARCH HANDLER (Cached Filter + Stable IDs) ─────
    private func handleSearchTextChange(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            matchingCustomers = []
            return
        }

        // Normalize: digits-only for phone comparisons
        func digits(_ s: String) -> String { s.filter(\.isNumber) }
        let qLower = trimmed.lowercased()
        let qDigits = digits(trimmed)

        // Filter cached list
        let filtered = customerDB.customers.filter { c in
            let nameHit = c.name.lowercased().contains(qLower)
            let phoneHit: Bool = {
                if qDigits.isEmpty { return false }
                return digits(c.phone).contains(qDigits)
            }()
            return nameHit || phoneHit
        }

        // De-duplicate by id (some datasets can surface dupes after formatting)
        var seen = Set<UUID>()
        let unique = filtered.filter { seen.insert($0.id).inserted }

        // Stable sort: by name, then phone
        let sorted = unique.sorted {
            if $0.name.caseInsensitiveCompare($1.name) == .orderedSame {
                return $0.phone < $1.phone
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        matchingCustomers = Array(sorted.prefix(25))
    }
    // END Search Handler

    // ───── Selection Helper ─────
    private func selectCustomer(_ customer: Customer) {
        withTransaction(Transaction(animation: .none)) {
            selectedCustomer = customer
            searchText = ""         // makes the list disappear
        }
        // TEMP: diagnostics so we can see if anyone overwrites later
        print("✅ selectCustomer:", customer.id.uuidString, customer.name, customer.phone)
    }
    // END Selection Helper

    
    // ───── SAVE HANDLER ─────
    func saveWorkOrder(onSuccess: (() -> Void)? = nil) {
        // ───── Required Field Validation ─────
        guard let customer = selectedCustomer else {
            alertMessage = "Please select or add a Customer before saving this WorkOrder."
            showAlert = true
            return
        }
        // END: Required Field Validation

        // ───── Build WorkOrder (ALL required fields) ─────
        // NOTE: Placeholder values where we haven't wired managers yet.
        // - createdBy / lastModifiedBy will come from UserManager
        // - dropdownSchemaVersion hard-coded to 1 until DropdownSchema exists
        let wo = WorkOrder(
            id: UUID().uuidString,            // if your model uses String; otherwise keep UUID()
            createdBy: "Tech",                // ⬅️ move this up, right after id
            customerId: customer.id.uuidString,
            customerName: customer.name,
            customerPhone: customer.phone,
            WO_Type: "Intake",
            imageURL: items.first?.imageUrls.first,
            timestamp: Date(),
            status: "Checked In",
            WO_Number: generateLocalWONumber(),
            flagged: flagged,
            tagId: nil,
            estimatedCost: nil,
            finalCost: nil,
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            lastModified: Date(),
            lastModifiedBy: "Tech",
            tagBypassReason: nil,
            isDeleted: false,
            notes: [],
            items: items        )


        // ───── END Build WorkOrder ─────

        // ───── Persist to Firestore (Codable) ─────
        do {
            let db = Firestore.firestore()
            try db.collection("workOrders")
                .document(wo.id ?? UUID().uuidString)   // unwrap: ensure non-optional doc id
                .setData(from: wo)
            
            // If a success callback was provided (e.g., to dismiss), call it.
            // Otherwise show the success alert (useful for unit/UI testing).
            savedWONumber = wo.WO_Number
            showSaveBanner = true

            // Wait ~2 sec, then call the success callback (which routes away)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onSuccess?()
            }

            // (Optional) Reset local form state for the next intake (kept as-is)
            selectedCustomer = nil
            searchText = ""
            matchingCustomers = []
            flagged = false
            items = [WO_Item.blank()]
            expandedIndex = 0


        } catch {
            alertMessage = "❌ Failed to save WorkOrder: \(error.localizedDescription)"
            showAlert = true
        }
        // ───── END Persist ─────
    }
    // END Save Handler

    // ───── Helper: Local WO Number (temp) ─────
    private func generateLocalWONumber() -> String {
        // Format: YYMMDD-### (temp counter = seconds mod 1000 to avoid collisions in dev)
        let df = DateFormatter()
        df.dateFormat = "yyMMdd"
        let day = df.string(from: Date())
        let suffix = String(format: "%03d", Int(Date().timeIntervalSince1970) % 1000)
        return "\(day)-\(suffix)"
    }
    // END Helper



    // ───── Action: Delete / Reset WO_Item ─────
    private func handleDeleteWOItem(_ index: Int) {
        if items.count > 1 {
            _ = withAnimation { items.remove(at: index) }   // ignore return explicitly
            // Keep expansion on a sensible neighbor
            if let current = expandedIndex, current == index {
                expandedIndex = max(0, min(index, items.count - 1))
            } else if let current = expandedIndex, current > index {
                expandedIndex = current - 1
            }
        } else {
            // Must always have ≥ 1 WO_Item: reset the lone item
            withAnimation { items[0] = WO_Item.blank() }   // ignore return explicitly
            expandedIndex = 0
        }
    }
    // END: Delete / Reset WO_Item

}
// END struct

// ───── PREVIEW ─────
#Preview {
    NewWorkOrderView()
}
// END Preview
