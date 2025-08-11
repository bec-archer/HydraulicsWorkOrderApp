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
    // END Prefill Helpers
    // ───── Item Header Helpers ─────
    private func itemTitle(for item: WO_Item) -> String {
        // Prefer dropdown “type” or fall back gracefully
        item.dropdowns["type"]?.capitalized ?? "WO_Item"
    }

    private func itemSubtitle(for item: WO_Item) -> String {
        // Show a quick at-a-glance detail, like size or color
        if let size = item.dropdowns["size"], !size.isEmpty {
            return size
        }
        if let color = item.dropdowns["color"], !color.isEmpty {
            return color
        }
        return "Details"
    }
    // END Item Header Helpers

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
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16)) // ↓ tighter bottom spacing

                // END Customer Lookup
                
                // ───── WORK ORDER FLAGS ─────
                Section(header: Text("Work Order Info")) {
                    Toggle("Flag this WorkOrder", isOn: $flagged)
                }
                // END Work Order Flags
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16)) // ↓ tighter top spacing
                
                // ───── WO_Item ENTRY ─────
                Section(header: Text("Equipment Items")) {
                    ForEach(items.indices, id: \.self) { idx in
                        WOItemAccordionRow(
                            item: $items[idx],
                            index: idx,
                            expandedIndex: $expandedIndex,
                            onDelete: handleDeleteWOItem   // ← add this
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
            // ───── Debounced onChange (prevents list swapping mid‑tap) ─────
            .onChange(of: searchText) { newValue in
                // Don’t recompute matches while the user is selecting a row
                guard !isPickingCustomer else { return }

                searchDebounce?.cancel()
                let task = DispatchWorkItem { handleSearchTextChange(newValue) }
                searchDebounce = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: task)
            }
            // END Debounced onChange
            
            // ───── DIAGNOSTIC: Who is overwriting selectedCustomer? ─────
            .onChange(of: selectedCustomer) { newValue in
                guard let c = newValue else { return }
                print("⚠️ selectedCustomer CHANGED:", c.id.uuidString, c.name, c.phone)
            }
            // END Diagnostic
            
            // ───── CUSTOMER INJECTION ─────

            // 🔁 Customer injected from NewCustomerModalView
            .onChange(of: selectedCustomer) {
                if let c = selectedCustomer {
                    print("📦 NewWorkOrderView RECEIVED CUSTOMER:", c.id.uuidString)       // TEMP LOG
                    print("👤 Injected Name/Phone:", c.name, c.phone)                       // TEMP LOG
                    searchText = ""
                    matchingCustomers = []
                    print("🧹 Cleared search/matches; summary card should now be visible.") // TEMP LOG
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
    func saveWorkOrder() {
        // ───── Required Field Validation ─────
        guard let customer = selectedCustomer else {
            // No customer selected: stop and inform the user.
            alertMessage = "Please select or add a Customer before saving this WorkOrder."
            showAlert = true
            return
        }
        // END: Required Field Validation

        // ───── Proceed with save (placeholder) ─────
        // Build WorkOrder object and persist to Firebase/SQLite here.
        // Using 'customer' is now safe because validation passed.
        print("✅ Proceeding to save WorkOrder for customer:", customer.name, customer.phone)

        // TODO: implement actual persistence flow in the next step.
        // ───── END Proceed with save (placeholder) ─────
    }
    // END Save Handler


    // ───── Action: Delete / Reset WO_Item ─────
    private func handleDeleteWOItem(_ index: Int) {
        if items.count > 1 {
            withAnimation { items.remove(at: index) }
            // Keep expansion on a sensible neighbor
            if let current = expandedIndex, current == index {
                expandedIndex = max(0, min(index, items.count - 1))
            } else if let current = expandedIndex, current > index {
                expandedIndex = current - 1
            }
        } else {
            // Must always have ≥ 1 WO_Item: reset the lone item
            withAnimation { items[0] = WO_Item.blank() }
            expandedIndex = 0
        }
    }
    // END: Delete / Reset WO_Item

}
// END struct



// ─────────────────────────────────────────────────────────────
// MARK: - WOItemAccordionRow
// Collapsible inline form for a single WO_Item.
// Shows "New Item" when empty. When expanded, includes a
// destructive "Delete Item" button (resets if it's the only item).
// ─────────────────────────────────────────────────────────────
private struct WOItemAccordionRow: View {
    @Binding var item: WO_Item
    let index: Int
    @Binding var expandedIndex: Int?
    let onDelete: (_ index: Int) -> Void  // ← parent-provided action

    // Control whether THIS row is expanded (single-expand behavior)
    private var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedIndex == index },
            set: { $0 ? (expandedIndex = index) : (expandedIndex = nil) }
        )
    }

    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            // ───── Expanded Content (full inline form) ─────
            AddWOItemFormView(item: $item)
                .padding(.top, 6)

            // ───── Danger Zone: Delete Item (expanded only) ─────

            HStack {
                Spacer()
                
                //Delete Circle Button (red circle with white X)
                Button {
                    onDelete(index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)             // circle size
                        .background(Color.red, in: Circle())      // red circle
                }
                .buttonStyle(.plain)                              // no default border
                .accessibilityLabel("Delete Item")
            }
            // END: Danger Zone

        }
        
        // ───── WO_Item Header Label ─────
        label: {
            HStack(spacing: 8) {
                Text(headerTitle(for: item))   // "New Item" (neutral) → "Item" (bold) after input
                    .font(hasUserEnteredData(item) ? .headline : .body)
                    .foregroundStyle(hasUserEnteredData(item) ? .primary : .secondary)

                Spacer()
                if let summary = summaryText(for: item) {
                    Text(summary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } // else: show nothing until user enters data
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
        }
        // END: WO_Item Header Label

    }
    // END: .body
    // ───── Helper: Did user enter anything yet? ─────
    private func hasUserEnteredData(_ item: WO_Item) -> Bool {
        // Treat true user input only; ignore empty defaults.
        if let tag = item.tagId, !tag.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if !item.imageUrls.isEmpty { return true }
        if !item.type.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if item.dropdowns.values.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { return true }
        if !item.reasonsForService.isEmpty { return true }
        if let notes = item.reasonNotes, !notes.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return false
    }
    // END Helper

    // ───── Helper: Header Title for WO_Item Row ─────
    private func headerTitle(for item: WO_Item) -> String {
        // Until the user interacts, keep it neutral and not bold.
        // After input, we switch to a generic "Item" title and let summary carry the details.
        return hasUserEnteredData(item) ? "Item" : "New Item"
    }

    // ───── Helper: Optional summary text (only if there’s data) ─────
    private func summaryText(for item: WO_Item) -> String? {
        guard hasUserEnteredData(item) else { return nil }  // nothing until user enters data
        var bits: [String] = []
        if let t = (item.type.isEmpty ? item.dropdowns["type"] : item.type), !t.isEmpty {
            bits.append(t)                      // Type
        }
        if let size = item.dropdowns["size"], !size.isEmpty {
            bits.append(size)                   // Size
        }
        if let color = item.dropdowns["color"], !color.isEmpty {
            bits.append(color)                  // Color
        }
        return bits.isEmpty ? nil : bits.joined(separator: " • ")
    }

    // END Helper

    

    // (Your next helper function or computed property starts here…)

}
// END: WOItemAccordionRow




// ───── PREVIEW ─────
#Preview {
    NewWorkOrderView()
}
// END Preview
