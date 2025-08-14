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
    @State private var flagged: Bool = false
    @State private var items: [WO_Item] = [WO_Item.blank()]
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var expandedIndex: Int? = nil
    @State private var showingNewCustomerModal: Bool = false   // ✅ fixed: had no Bool type
    @State private var searchDebounce: DispatchWorkItem?
    @State private var showSaveBanner: Bool = false
    @State private var savedWONumber: String = ""
    
    @State private var draftWOId: String = UUID().uuidString

    
    // 🔍 Search logic is now isolated
    @StateObject private var customerSearch = CustomerSearchViewModel()

    
    // ───── Prefill Helpers (derive from customerSearch.searchText) ─────
    private var prefillNameFromSearch: String {
        let trimmed = customerSearch.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        return digits.count >= 3 ? "" : trimmed   // numbers ⇒ phone, else ⇒ name
    }
    private var prefillPhoneFromSearch: String {
        let trimmed = customerSearch.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        return digits.count >= 3 ? trimmed : ""   // digits ⇒ phone, else blank
    }
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appState = AppState.shared

    // END Prefill Helpers

    // ───── Readiness Helpers (hide Check In buttons until valid) ─────
    private func itemHasType(_ item: WO_Item) -> Bool {
        // Type can live in item.type or dropdowns["type"] depending on caller
        let t = item.type.isEmpty ? (item.dropdowns["type"] ?? "") : item.type
        return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasSelectedType: Bool {
        items.contains { itemHasType($0) }
    }

    // Only count uploaded photos (thumbs or full URLs), not local images
    private var hasAnyUploadedPhoto: Bool {
        items.contains { !$0.thumbUrls.isEmpty || !$0.imageUrls.isEmpty }
    }

    private var canShowCheckInButtons: Bool {
        // ✅ Require: Customer + a Type + at least one **uploaded** photo (any item)
        (selectedCustomer != nil) && hasSelectedType && hasAnyUploadedPhoto
    }

    // END Readiness Helpers
    
    // ───── Customer Lookup Section (extracted to ease type-checking) ─────
    @ViewBuilder
    private func customerLookupSection() -> some View {
        // Required field header
        HStack(spacing: 4) {
            Text("Customer")
                .font(.headline)
            Text("*")
                .foregroundColor(.red)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)

        GroupBox {
            if let customer = selectedCustomer {
                // Selected customer summary with inline Clear
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customer.name).font(.headline)
                        Text(customer.phone).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        selectedCustomer = nil
                        customerSearch.resetSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .imageScale(.large)
                            .padding(.leading, 4)
                            .accessibilityLabel("Clear selected customer")
                    }
                }
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // TextField OUTSIDE Form to avoid accessory constraint thrash
                    TextField("Search by name or phone", text: $customerSearch.searchText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.default)

                    if !customerSearch.matchingCustomers.isEmpty {
                        ForEach(customerSearch.matchingCustomers, id: \.id) { customer in
                            Button {
                                customerSearch.isPickingCustomer = true
                                selectCustomer(customer)
                                customerSearch.resetSearch()
                                DispatchQueue.main.async { customerSearch.isPickingCustomer = false }
                                print("👆 PICKED:", customer.id.uuidString, customer.name, customer.phone)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(customer.name)
                                    Text(customer.phone).font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } else if !customerSearch.searchText.isEmpty {
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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(nil, value: customerSearch.matchingCustomers.count) // no implicit animation during typing
    }
    // END Customer Lookup Section


    // ───── BODY ─────
    var body: some View {
        NavigationStack {
            // ───── CUSTOMER LOOKUP (extracted) ─────
            customerLookupSection()
            // END Customer Lookup

            
            // ───── WO_Items (Accordion List) ─────
            ScrollView {
                woItemsSection()
            }
            // END WO_Items (Accordion List)


            
            .navigationTitle("New Work Order")
            
            // ───── Toolbar: Check In (Save) ─────
            .toolbar { toolbarContent() }
            // END toolbar

            // ───── Sticky Bottom Save Button (backup to toolbar) ─────
            .safeAreaInset(edge: .bottom) { stickyCheckIn() }
            // END sticky bottom button

            // ───── Quiet iPad keyboard accessory + make keyboard dismiss on scroll ─────
            .scrollDismissesKeyboard(.immediately)
            // END keyboard/scroll settings
         
         .alert(Text("Status"), isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            // ───── SAFE ONCHANGE FOR iOS 16+17 ─────

            
            // ───── CUSTOMER PICKED (observe only; no state writes here) ─────
            .onChange(of: selectedCustomer?.id) { newID in
                guard let newID = newID else { return }
                print("✅ selectedCustomer changed → \(newID)")
                // NOTE: selectCustomer(_:) already resets the search UI.
            }
            // ─────────────────────────────────────────────────────

            .onAppear {
                if expandedIndex == nil {
                    expandedIndex = items.indices.first
                }
            }

            // END onChange

            // ───── Toast Banner Overlay ─────
            .overlay(saveBannerOverlay())
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

    }
    // END .body
    
    // ───── Extracted WO_Items Section (reduces type-checker load) ─────
    @ViewBuilder
    private func woItemsSection() -> some View {
        VStack(spacing: 12) {

            // Using Array(...) makes the sequence concrete and faster to type-check
            ForEach(Array(items.indices), id: \.self) { idx in
                WOItemAccordionRow(
                    index: idx,
                    woId: draftWOId,               // ⬅️ pass parent WO id
                    items: $items,
                    expandedIndex: $expandedIndex,
                    onDelete: { indexToDelete in
                        handleDeleteWOItem(indexToDelete)
                    }
                )
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                )
            }

            // ➕ Add Item button
            Button {
                withAnimation {
                    items.append(WO_Item.blank())
                    expandedIndex = items.indices.last
                }
            } label: {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .modifier(UIConstants.Buttons.yellowButtonStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    // END Extracted WO_Items Section
    // ───── Toolbar Content (extracted) ─────
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {

        // (Removed in NewWorkOrderView) Sidebar toggle intentionally hidden here to avoid duplicate buttons.


        // Right: Check In button (only when valid)
        if canShowCheckInButtons {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveWorkOrder {
                        appState.currentView = .activeWorkOrders
                    }
                } label: {
                    Text("Check In Work Order")
                        .modifier(UIConstants.Buttons.yellowButtonStyle())
                }
                .buttonStyle(.plain)
            }
        }
    }
    // END Toolbar Content



    // ───── Sticky Check-In (extracted) ─────
    @ViewBuilder
    private func stickyCheckIn() -> some View {
        if canShowCheckInButtons {
            // ───── Sticky bar container (material + divider) ─────
            VStack(spacing: 10) {
                // Thin divider to separate from content above (iPad friendly)
                Divider()
                    .padding(.top, 2)

                // Primary action
                // Primary action
                Button {
                    saveWorkOrder {
                        // Prefer stack-based return when NewWorkOrderView was pushed from ActiveWorkOrdersView
                        dismiss()
                        // Also set router target if we’re inside RouterView (login not bypassed)
                        appState.currentView = .activeWorkOrders
                    }
                } label: {
                    Text("Check In Work Order")
                        .modifier(UIConstants.Buttons.yellowButtonStyle())
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("checkInWorkOrder_sticky")
                }
                .buttonStyle(.plain)

            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 10)     // a bit of breathing room above the Home indicator
            .background(.ultraThinMaterial)
            .ignoresSafeArea(.keyboard, edges: .bottom) // prevent keyboard from pushing this into accessory space
            // ───── END sticky bar container ─────

        } else {
            EmptyView()
        }

    }
    // END Sticky Check-In

    // ───── Save Banner Overlay (extracted) ─────
    @ViewBuilder
    private func saveBannerOverlay() -> some View {
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
    }
    // END Save Banner Overlay
    
    // ───── Availability-Safe: Hide Keyboard Toolbar (SDK-agnostic no-op) ─────
    private struct KeyboardToolbarHidden: ViewModifier {
        @ViewBuilder
        func body(content: Content) -> some View {
            content // no-op to avoid referencing .keyboard on older SDKs
        }
    }
    // END



    // ───── Selection Helper ─────
    private func selectCustomer(_ customer: Customer) {
        // Avoid recursive update if already selected
        if selectedCustomer?.id == customer.id {
            print("⚠️ selectCustomer: already selected, skipping redundant update.")
            return
        }

        withTransaction(Transaction(animation: .none)) {
            selectedCustomer = customer
            customerSearch.resetSearch()
        }

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
        // ───── Async: Get next WO_Number then save ─────
        WorkOrdersDatabase.shared.generateNextWONumber { result in
            let nextNumber: String
            switch result {
            case .success(let num):
                nextNumber = num
            case .failure(let err):
                // Fallback to time-based format to avoid blocking save
                print("⚠️ Using fallback WO_Number due to query error: \(err.localizedDescription)")
                let seq = Int(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
                nextNumber = WorkOrderNumberGenerator.make(sequence: seq)

            }

            // Build WorkOrder with resolved number
            let wo = WorkOrder(
                id: nil,                    // keep ID consistent with Storage folder
                createdBy: "Tech",
                customerId: customer.id.uuidString,
                customerName: customer.name,
                customerPhone: customer.phone,
                WO_Type: "Intake",
                imageURL: items.first?.thumbUrls.first ?? items.first?.imageUrls.first,
                timestamp: Date(),
                status: "Checked In",
                WO_Number: nextNumber,
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
                items: items
            )
            // ───── END Build WorkOrder ─────

            // ───── Persist to Firestore (Codable) ─────
            do {
                let db = Firestore.firestore()
                try db.collection("workOrders")
                    .document(draftWOId)
                    .setData(from: wo)

                // UI updates on main
                DispatchQueue.main.async {
                    savedWONumber = wo.WO_Number
                    showSaveBanner = true

                    // Route back to Active immediately (caller sets AppState)
                    onSuccess?()

                    // Reset local form state for the next intake
                    selectedCustomer = nil
                    customerSearch.resetSearch()
                    flagged = false
                    items = [WO_Item.blank()]
                    expandedIndex = 0
                    draftWOId = UUID().uuidString
                }


            } catch {
                DispatchQueue.main.async {
                    alertMessage = "❌ Failed to save WorkOrder: \(error.localizedDescription)"
                    showAlert = true
                }
            }
            // ───── END Persist ─────
        }
        // ───── END Async save ─────

    }
    // END Save Handler

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
        .environmentObject(AppState.shared)
}
// END PREVIEW
