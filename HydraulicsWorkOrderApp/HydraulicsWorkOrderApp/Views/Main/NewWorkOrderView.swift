//
//  NewWorkOrderView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 NewWorkOrderView.swift
// Updated to show inline WO_Item forms, collapsible cards
// ─────────────────────────────────────────────────────────────

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

// ───── VIEW: NewWorkOrderView ─────
struct NewWorkOrderView: View {
    @State private var selectedCustomer: Customer?
    @State private var searchText = ""
    @State private var matchingCustomers: [Customer] = []
    @State private var flagged = false
    @State private var items: [WO_Item] = [WO_Item.empty()]
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingNewCustomerModal = false

    // ───── Collapsible Items State ─────
    @State private var expandedItemIDs: Set<UUID> = []
    // END

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
                } // END Customer Lookup

                // ───── WORK ORDER FLAGS ─────
                Section(header: Text("Work Order Info")) {
                    Toggle("Flag this Work Order", isOn: $flagged)
                } // END Work Order Info

                // ───── EQUIPMENT ITEMS (Collapsible) ─────
                Section(header: Text("Equipment Items")) {
                    ForEach($items) { $item in
                        // Resolve index safely without relying on Enumerated+Bindings (which can crash)
                        let index = items.firstIndex(where: { $0.id == item.id }) ?? 0
                        let isExpanded = expandedItemIDs.contains(item.id)
                        let headerTitle = isExpanded
                            ? "Item \(index + 1)"
                            : headerSummary(for: item)

                        VStack(alignment: .leading, spacing: 10) {
                            // HEADER ROW
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(swatchColor(for: item.dropdowns["color"]))
                                    .frame(width: 14, height: 14)

                                Text(headerTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer()

                                Button { toggleExpanded(item.id) } label: {
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                }
                                .buttonStyle(.plain)

                                Button { duplicate(item) } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)

                                Button(role: .destructive) { delete(item) } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { toggleExpanded(item.id) }

                            // BODY
                            if isExpanded {
                                AddWOItemFormView(item: $item)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground)))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1))
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                        .padding(.vertical, 6)
                    }

                    // End of ForEach

                    Button {
                        // Add new item and auto-collapse others, expand the new one
                        let new = WO_Item.empty()
                        items.append(new)
                        expandedItemIDs = [new.id]
                    } label: {
                        Label("Add Another Item", systemImage: "plus.circle")
                            .font(.headline)
                            .padding(.vertical, 4)
                    }
                    .tint(.yellow)
                    .foregroundStyle(.black)
                } // END Equipment Items

                // ───── SAVE ─────
                Section {
                    Button("✅ Save Work Order") {
                        saveWorkOrder()
                    }
                } // END Save
            }
            .navigationTitle("New Work Order")
            .onAppear {
                if expandedItemIDs.isEmpty, let first = items.first { expandedItemIDs = [first.id] }
            }
            .alert(Text("Status"), isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }

            // ───── SAFE ONCHANGE FOR iOS 16+17 ─────
            .onChange(of: searchText) { newValue in
                handleSearchTextChange(newValue)
            }

        }
    } // END .body

    // ───── Customer search handler ─────
    private func handleSearchTextChange(_ newValue: String) {
        let q = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        matchingCustomers = []

        // Avoid noisy queries and accidental blanks
        guard q.count >= 3 else { return }

        let lower = q.lowercased()
        Firestore.firestore().collection("customers").getDocuments { snapshot, _ in
            if let docs = snapshot?.documents {
                let all = docs.compactMap { try? $0.data(as: Customer.self) }
                matchingCustomers = all.filter {
                    $0.name.lowercased().contains(lower) || $0.phone.contains(lower)
                }
            }
        }
    }


    // ───── SAVE HANDLER ─────
    // Keeping your existing field names/types to avoid breaking your current DB layer.
    private func saveWorkOrder() {
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
                expandedItemIDs = [] // collapse after save
            case .failure(let error):
                alertMessage = "❌ Failed to save: \(error.localizedDescription)"
            }
            showAlert = true
        }
    }

    // ───── Header Helpers (safe, no String extensions needed) ─────
    private func headerSummary(for item: WO_Item) -> String {
        // Trim everything so we don't display stray spaces
        let type = (item.dropdowns["type"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let machineType = (item.dropdowns["machineType"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let machineBrand = (item.dropdowns["machineBrand"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let typePart = type.isEmpty ? "Type" : type
        let machine = [machineType, machineBrand]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

        // If machine is empty, just return the type; otherwise “Type  —  Machine • Brand”
        return machine.isEmpty ? typePart : "\(typePart)  —  \(machine)"
    }


    private func toggleExpanded(_ id: UUID) {
        if expandedItemIDs.contains(id) {
            expandedItemIDs.remove(id)
        } else {
            expandedItemIDs = [id] // keep only one open for compactness
        }
    }

    private func duplicate(_ item: WO_Item) {
        var copy = item
        copy.id = UUID()
        items.append(copy)
        expandedItemIDs = [copy.id]
    }

    private func delete(_ item: WO_Item) {
        items.removeAll { $0.id == item.id }
        expandedItemIDs.remove(item.id)
    }

    // Color swatch lookup using DropdownManager’s color list
    private func swatchColor(for label: String?) -> Color {
        guard let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else {
            return Color(.systemGray4)
        }
        if let match = DropdownManager.shared.options["color"]?.first(where: { $0.label == label || $0.value == label }),
           let hex = match.colorHex,
           let c = Color(hex: hex) {
            return c
        }
        return Color(.systemGray4)
    }
    
    // Collapsed-only summary: include only chosen (non-empty) fields
    private func collapsedSummary(for item: WO_Item) -> String {
        let type = (item.dropdowns["type"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let machineType = (item.dropdowns["machineType"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let machineBrand = (item.dropdowns["machineBrand"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let color = (item.dropdowns["color"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if !type.isEmpty { parts.append(type) }

        let machine = [machineType, machineBrand].filter { !$0.isEmpty }.joined(separator: " • ")
        if !machine.isEmpty { parts.append(machine) }

        if !color.isEmpty, color != "Other" { parts.append(color) }

        // If truly nothing selected yet, show a minimal hint instead of placeholders
        return parts.isEmpty ? "New Item" : parts.joined(separator: "  —  ")
    }

} // END NewWorkOrderView

// ───── Small Utilities (file-scope; no view state references) ─────
// Hex to Color initializer
private extension Color {
    init?(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.count == 6, let rgb = Int(clean, radix: 16) else { return nil }
        self = Color(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}



// ───── Preview Template ─────
#Preview {
    NewWorkOrderView()
}
