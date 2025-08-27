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
    @State private var selectedCustomer: Customer? // nil = no selection
    @State private var flagged: Bool = false // WO-level flag
    @State private var items: [WO_Item] = [WO_Item.blank()] // start with one blank item
    @State private var showAlert: Bool = false // for validation errors
    @State private var alertMessage: String = "" // alert content
    @State private var expandedIndices: Set<Int> = []    // which WO_Items are expanded
    @State private var showingNewCustomerModal: Bool = false   // ✅ fixed: had no Bool type
    @State private var searchDebounce: DispatchWorkItem?  // for debounced search
    @State private var showSaveBanner: Bool = false // show "Saved" banner briefly
    @State private var savedWONumber: String = "" // for "WO-1234 Saved!" banner
    
    @State private var showValidationNudge: Bool = false   // ⬅️ NEW: to trigger validation highlight
    
    @State private var draftWOId: String = UUID().uuidString // unique ID for photo storage namespace

    
    // 🔍 Search logic is now isolated
    @StateObject private var customerSearch = CustomerSearchViewModel() // manages search state

    
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

    // Also accept thumbs as evidence of a captured photo
    private func itemHasPhoto(_ item: WO_Item) -> Bool {
        return !item.thumbUrls.isEmpty || !item.imageUrls.isEmpty
    }

    // Completion/blank/partial logic (mirrors AddWOItemFormView)
    private func isCompleteItem(_ item: WO_Item) -> Bool {
        return itemHasType(item) && itemHasPhoto(item) && !item.reasonsForService.isEmpty
    }
    private func isBlankItem(_ item: WO_Item) -> Bool {
        return !itemHasType(item) && !itemHasPhoto(item)
    }
    private func isPartiallyFilledItem(_ item: WO_Item) -> Bool {
        let hasType = itemHasType(item)
        let hasPhoto = itemHasPhoto(item)
        let hasReasons = !item.reasonsForService.isEmpty
        return (hasType && !hasPhoto) || (!hasType && hasPhoto) || (hasType && hasPhoto && !hasReasons)
    }

    private var hasAtLeastOneCompleteItem: Bool {
        items.contains { isCompleteItem($0) }
    }
    private var hasAnyPartialItem: Bool {
        items.contains { isPartiallyFilledItem($0) }
    }
    private var canShowCheckInButtons: Bool {
        // ✅ Require: Customer + ALL items must be complete (no partial items allowed)
        (selectedCustomer != nil) && items.count > 0 && items.allSatisfy { isCompleteItem($0) }
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
                        HStack(spacing: 4) {
                            Text(customer.phone).font(.subheadline).foregroundStyle(.secondary)
                            if let company = customer.company, !company.isEmpty {
                                Text("•").font(.subheadline).foregroundStyle(.secondary)
                                Text(company).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
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
                    TextField("Search by name, phone, or company", text: $customerSearch.searchText)
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
                                    HStack(spacing: 4) {
                                        Text(customer.phone).font(.caption).foregroundStyle(.secondary)
                                        if let company = customer.company, !company.isEmpty {
                                            Text("•").font(.caption).foregroundStyle(.secondary)
                                            Text(company).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
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
            .onChange(of: selectedCustomer?.id) { _, _ in
                guard let newID = selectedCustomer?.id else { return }
                print("✅ selectedCustomer changed → \(newID)")
                // NOTE: selectCustomer(_:) already resets the search UI.
            }
            // ─────────────────────────────────────────────────────

            .onAppear {
                                    if expandedIndices.isEmpty {
                        expandedIndices.insert(items.indices.first!)
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
        .withOfflineStatus() // Add offline status indicator
    }
    // END .body
    
    // ───── Extracted WO_Items Section (reduces type-checker load) ─────
    @ViewBuilder
    private func woItemsSection() -> some View {
        VStack(spacing: 12) {

            /// Using binding-based enumeration prevents crashes when `items` mutates (e.g., on Check In).
            /// Each row is keyed by `item.id`, not by index.
            // ⚠️ Use binding-based ForEach keyed by item.id to avoid index invalidation during saves
            ForEach(Array($items.enumerated()), id: \.element.id) { idx, $woItem in
                WOItemAccordionRow(
                    index: idx,
                    woId: draftWOId,
                    items: $items,
                    expandedIndices: $expandedIndices,
                    showValidationNudge: $showValidationNudge,   // ⬅️ NEW Binding
                    onDelete: { indexToDelete in
                        handleDeleteWOItem(indexToDelete)
                    }
                )
                .id(woItem.id) // stabilize identity per WO_Item (use value, not Binding)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                )
            }

            // ➕ Add Item button
            Button {
                print("🔍 Add Item button pressed. items count: \(items.count)")
                
                // Debug: Check the state of each item
                for (index, item) in items.enumerated() {
                    let hasType = itemHasType(item)
                    let hasPhoto = itemHasPhoto(item)
                    print("🔍 Item \(index): type='\(item.type)', hasType=\(hasType), imageUrls.count=\(item.imageUrls.count), thumbUrls.count=\(item.thumbUrls.count), hasPhoto=\(hasPhoto)")
                }

                // Always allow adding new items (no blocking based on partial items)
                showValidationNudge = false
                print("🔄 Adding new item. Current count: \(items.count)")
                withAnimation {
                    let newItem = WO_Item.blank()
                    print("🆕 Created new item with ID: \(newItem.id)")
                    items.append(newItem)
                    expandedIndices.insert(items.indices.last!)
                }
                print("✅ Added new item. New count: \(items.count), expandedIndices: \(expandedIndices)")
            } label: {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.vertical, 8)
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
                        // Route back to Active Work Orders even when saving via toolbar button
                        dismiss()
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

        // ───── Discard Blank Items; Block on Partials ─────
        // 1) Drop items with neither type nor photo (true blanks)
        let nonBlankItems = items.filter { !isBlankItem($0) }

        // 2) If any partially filled item remains, bump user to finish it
        // 2) If any partially filled item remains, bump user to finish it
        if let firstPartialIdx = nonBlankItems.firstIndex(where: { isPartiallyFilledItem($0) }) {
            showValidationNudge = true                 // ⬅️ NEW
            expandedIndices.insert(firstPartialIdx)
            alertMessage = "Please finish the highlighted WO_Item. Each item needs a Type and at least one Photo."
            showAlert = true
            return
        }

        // 3) Must have at least one complete item to proceed
        guard !nonBlankItems.isEmpty, nonBlankItems.contains(where: { isCompleteItem($0) }) else {
            alertMessage = "Add at least one WO_Item with a Type and Photo before checking in."
            showAlert = true
            return
        }

        // ───── DEBUG LOG ─────
        print("📝 DEBUG Save Attempt")
        print("Customer: \(customer.name) – \(customer.phone)")
        print("WO_Items count: \(items.count)")
        for (i, item) in items.enumerated() {
            print("  Item[\(i)] id=\(item.id) type=\(item.type) " +
                  "thumbs=\(item.thumbUrls.count) images=\(item.imageUrls.count)")
        }

        // ───── Snapshot items to avoid mutation during iteration ─────
        let itemsSnapshot = nonBlankItems

        // Example: build payload with map (no indexing)
        let builtItems: [WO_Item] = itemsSnapshot.map { $0 }
        

         
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
                id: nil,                                   // @DocumentID → Firestore assigns; don’t seed this
                createdBy: "Tech",
                customerId: customer.id.uuidString,
                customerName: customer.name,
                customerCompany: customer.company,
                customerEmail: customer.email,
                customerTaxExempt: customer.taxExempt,
                customerPhone: customer.phone,
                WO_Type: "Intake",
                imageURL: nil,                             // Will be set when images are uploaded
                imageURLs: [],                             // Initialize as empty array instead of nil
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
                items: builtItems
            )
            // ───── END Build WorkOrder ─────

            // ───── Persist via WorkOrdersDatabase (auto-ID; prevents overwrite) ─────
            #if DEBUG
            print("🚀 Attempting to save WorkOrder: \(wo.WO_Number)")
            #endif
            
            // Check network connectivity first
            if NetworkMonitor.shared.isConnected {
                // Online: Save to Firestore
                WorkOrdersDatabase.shared.addWorkOrder(wo) { result in
                    switch result {
                    case .success(let docId): // Get the actual Firestore document ID
                        DispatchQueue.main.async {
                            #if DEBUG
                            print("✅ WorkOrder saved successfully: \(wo.WO_Number) with Firestore ID: \(docId)")
                            #endif
                            savedWONumber = wo.WO_Number
                            showSaveBanner = true

                            // 🚩 Make a fresh storage namespace immediately for the NEXT WorkOrder
                            draftWOId = UUID().uuidString

                            // Route back to Active immediately (caller sets AppState)
                            onSuccess?()

                            // Defer form reset one tick to avoid tearing down subviews mid-update
                            DispatchQueue.main.async {
                                withAnimation(.none) {
                                    selectedCustomer = nil
                                    customerSearch.resetSearch()
                                    flagged = false
                                    items = [WO_Item.blank()]
                                    expandedIndices = [0]
                                }
                            }
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            alertMessage = "❌ Failed to save WorkOrder: \(error.localizedDescription)"
                            showAlert = true
                        }
                    }
                }
            } else {
                // Offline: Save to local cache and queue for sync
                #if DEBUG
                print("📱 Offline mode: Saving work order to local cache")
                #endif
                
                // Add to local cache immediately for UI visibility
                var offlineWO = wo
                offlineWO.id = UUID().uuidString // Generate temporary local ID
                WorkOrdersDatabase.shared.workOrders.append(offlineWO)
                
                // Queue for sync when network is restored
                for item in wo.items {
                    OfflineManager.shared.createWorkOrderOffline(item)
                }
                
                DispatchQueue.main.async {
                    savedWONumber = wo.WO_Number
                    showSaveBanner = true
                    alertMessage = "📱 Work order saved offline. Will sync when connection is restored."
                    showAlert = true

                    // 🚩 Make a fresh storage namespace immediately for the NEXT WorkOrder
                    draftWOId = UUID().uuidString

                    // Route back to Active immediately (caller sets AppState)
                    onSuccess?()

                    // Defer form reset one tick to avoid tearing down subviews mid-update
                    DispatchQueue.main.async {
                        withAnimation(.none) {
                            selectedCustomer = nil
                            customerSearch.resetSearch()
                            flagged = false
                            items = [WO_Item.blank()]
                            expandedIndices = [0]
                        }
                    }
                }
            }
        }
        // ───── END Async save ─────

    }
    // END Save Handler

    // ───── Action: Delete / Reset WO_Item ─────
    private func handleDeleteWOItem(_ index: Int) {
        if items.count > 1 {
            _ = withAnimation { items.remove(at: index) }   // ignore return explicitly
            // Keep expansion on a sensible neighbor
            if expandedIndices.contains(index) {
                expandedIndices.remove(index)
                if items.count > 0 {
                    expandedIndices.insert(max(0, min(index, items.count - 1)))
                }
            } else {
                // Adjust indices for items after the deleted one
                let newExpandedIndices = expandedIndices.compactMap { expandedIndex in
                    if expandedIndex > index {
                        return expandedIndex - 1
                    } else {
                        return expandedIndex
                    }
                }
                expandedIndices = Set(newExpandedIndices)
            }
        } else {
            // Must always have ≥ 1 WO_Item: reset the lone item
            withAnimation { items[0] = WO_Item.blank() }   // ignore return explicitly
            expandedIndices = [0]
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
