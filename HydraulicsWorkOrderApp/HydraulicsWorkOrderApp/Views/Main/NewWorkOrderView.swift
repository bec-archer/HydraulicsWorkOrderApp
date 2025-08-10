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
            .onChange(of: searchText) {
                handleSearchTextChange(searchText)
            }
            
            .onAppear {
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
        // ...
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
            Divider().padding(.top, 12)

            HStack {
                Spacer()
                Button(role: .destructive) {
                    onDelete(index)
                } label: {
                    Label("Delete Item", systemImage: "trash")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
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
