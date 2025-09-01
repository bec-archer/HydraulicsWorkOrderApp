//
//  NewWorkOrderView_Refactored.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 NewWorkOrderView_Refactored.swift
// Refactored version using NewWorkOrderViewModel for better separation of concerns
// ─────────────────────────────────────────────────────────────

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine
import FirebaseStorage

// MARK: - ViewModel (Temporarily included for testing)
@MainActor
class NewWorkOrderViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedCustomer: Customer?
    @Published var items: [WO_Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var canCheckIn = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let workOrdersDB = WorkOrdersDatabase.shared
    private let customerDB = CustomerDatabase.shared
    // TODO: Re-enable after fixing module resolution
    // private let imageService = ImageManagementService.shared
    
    // MARK: - Computed Properties
    var workOrderNumber: String {
        WorkOrderNumberGenerator.make(sequence: Int(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000)))
    }
    
    var hasValidCustomer: Bool {
        selectedCustomer != nil
    }
    
    var hasValidItems: Bool {
        !items.isEmpty && items.allSatisfy { item in
            itemHasType(item) && 
            itemHasPhoto(item) && 
            !item.reasonsForService.isEmpty
        }
    }
    
    // MARK: - Validation Helpers
    private func itemHasType(_ item: WO_Item) -> Bool {
        let t = item.type.isEmpty ? (item.dropdowns["type"] ?? "") : item.type
        return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func itemHasPhoto(_ item: WO_Item) -> Bool {
        return !item.thumbUrls.isEmpty || !item.imageUrls.isEmpty
    }

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
    
    // MARK: - Initialization
    init() {
        setupBindings()
        addInitialItem()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        Publishers.CombineLatest3(
            $selectedCustomer,
            $items,
            $isLoading
        )
        .map { customer, items, loading in
            guard !loading else { return false }
            guard customer != nil else { return false }
            guard !items.isEmpty else { return false }
            return items.allSatisfy { item in
                self.itemHasType(item) && 
                self.itemHasPhoto(item) && 
                !item.reasonsForService.isEmpty
            }
        }
        .assign(to: &$canCheckIn)
    }
    
    // MARK: - Public Methods
    func addItem() {
        var newItem = WO_Item.blank()
        // Generate WO Item ID for the new item
        let itemIndex = items.count
        newItem.woItemId = WO_Item.generateWOItemId(woNumber: workOrderNumber, itemIndex: itemIndex)
        items.append(newItem)
    }
    
    func removeItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        items.remove(at: index)
        
        // Regenerate WO Item IDs for remaining items to maintain sequential order
        for (itemIndex, _) in items.enumerated() {
            items[itemIndex].woItemId = WO_Item.generateWOItemId(woNumber: workOrderNumber, itemIndex: itemIndex)
        }
        
        if items.isEmpty {
            addInitialItem()
        }
    }
    
    func updateItem(_ item: WO_Item, at index: Int) {
        guard index >= 0 && index < items.count else { return }
        items[index] = item
    }
    
    // MARK: - Image Management
    
    /// Upload images for a specific item
    func uploadImages(_ images: [UIImage], for itemIndex: Int) async {
        // TODO: Re-enable after fixing module resolution
        print("Image upload temporarily disabled - module resolution issue")
    }
    
    /// Delete an image from a specific item
    func deleteImage(_ imageURL: String, from itemIndex: Int) async {
        // TODO: Re-enable after fixing module resolution
        print("Image deletion temporarily disabled - module resolution issue")
    }
    
    /// Get image URLs for a specific item
    func getImageURLs(for itemIndex: Int) async -> [String] {
        // TODO: Re-enable after fixing module resolution
        return []
    }
    
    func saveWorkOrder() async {
        guard let customer = selectedCustomer else {
            setError("Please select or add a Customer before saving this WorkOrder.")
            return
        }
        
        let nonBlankItems = items.filter { !isBlankItem($0) }
        
        if nonBlankItems.contains(where: { isPartiallyFilledItem($0) }) {
            setError("Please finish the highlighted WO_Item. Each item needs a Type and at least one Photo.")
            return
        }
        
        guard !nonBlankItems.isEmpty, nonBlankItems.contains(where: { isCompleteItem($0) }) else {
            setError("Add at least one WO_Item with a Type and Photo before checking in.")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔍 SAVING WORK ORDER: \(workOrderNumber)")
            print("  Customer: \(customer.name)")
            print("  Items to save: \(nonBlankItems.count)")
            
            // Debug each item being saved
            for (i, item) in nonBlankItems.enumerated() {
                print("  Item \(i): type='\(item.type)', images=\(item.imageUrls.count), reasons=\(item.reasonsForService.count)")
            }
            
            let itemsSnapshot = nonBlankItems
            let builtItems: [WO_Item] = itemsSnapshot.map { $0 }
            
            let workOrder = WorkOrder(
                id: nil,
                createdBy: "Tech",
                customerId: customer.id.uuidString,
                customerName: customer.name,
                customerCompany: customer.company,
                customerEmail: customer.email,
                customerTaxExempt: customer.taxExempt,
                customerPhone: customer.phone,
                WO_Type: "Intake",
                imageURL: nil,
                imageURLs: [],
                timestamp: Date(),
                status: "Checked In",
                WO_Number: workOrderNumber,
                flagged: false,
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
            
            print("🚀 Saving to Firebase...")
            try await withCheckedThrowingContinuation { continuation in
                workOrdersDB.addWorkOrder(workOrder) { result in
                    switch result {
                    case .success(let docId):
                        print("✅ SAVED SUCCESSFULLY: \(workOrder.WO_Number) -> ID: \(docId)")
                        continuation.resume()
                    case .failure(let error):
                        print("❌ SAVE FAILED: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            
        } catch {
            print("❌ SAVE ERROR: \(error.localizedDescription)")
            setError("Failed to save work order: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func resetForm() async {
        selectedCustomer = nil
        items.removeAll()
        addInitialItem()
        errorMessage = nil
        showError = false
    }
    
    private func addInitialItem() {
        if items.isEmpty {
            var newItem = WO_Item.blank()
            // Generate WO Item ID for the initial item
            newItem.woItemId = WO_Item.generateWOItemId(woNumber: workOrderNumber, itemIndex: 0)
            items.append(newItem)
        }
    }
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - View
struct NewWorkOrderView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = NewWorkOrderViewModel()
    
    // MARK: - UI State (View-specific only)
    @State private var expandedIndices: Set<Int> = []
    @State private var showingNewCustomerModal: Bool = false
    @State private var showSaveBanner: Bool = false
    @State private var savedWONumber: String = ""
    @State private var showValidationNudge: Bool = false
    @State private var draftWOId: String = UUID().uuidString
    
    // MARK: - Dependencies
    @StateObject private var customerSearch = CustomerSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appState = AppState.shared
    
    // MARK: - Computed Properties
    private var prefillNameFromSearch: String {
        let trimmed = customerSearch.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        return digits.count >= 3 ? "" : trimmed
    }
    
    private var prefillPhoneFromSearch: String {
        let trimmed = customerSearch.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        return digits.count >= 3 ? trimmed : ""
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Customer Lookup Section
                customerLookupSection()
                
                // Work Order Items Section
                ScrollView {
                    woItemsSection()
                }
            }
            .navigationTitle("New Work Order")
            .toolbar { toolbarContent() }
            .safeAreaInset(edge: .bottom) { stickyCheckIn() }
            .scrollDismissesKeyboard(.immediately)
            
            // Alerts and Sheets
            .alert("Validation Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .overlay(saveBannerOverlay())
            .sheet(isPresented: $showingNewCustomerModal) {
                NewCustomerModalView(
                    prefillName: prefillNameFromSearch,
                    prefillPhone: prefillPhoneFromSearch,
                    selectedCustomer: $viewModel.selectedCustomer
                )
            }
            
            // Lifecycle
            .onAppear {
                setupInitialState()
            }
            .onChange(of: viewModel.selectedCustomer?.id) { _, _ in
                handleCustomerSelection()
            }
        }
        .withOfflineStatus()
    }
    
    // MARK: - Customer Lookup Section
    @ViewBuilder
    private func customerLookupSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                if let customer = viewModel.selectedCustomer {
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
                            viewModel.selectedCustomer = nil
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
            .animation(nil, value: customerSearch.matchingCustomers.count)
        }
    }
    
    // MARK: - Work Order Items Section
    @ViewBuilder
    private func woItemsSection() -> some View {
        VStack(spacing: 12) {
            ForEach(Array($viewModel.items.enumerated()), id: \.element.id) { idx, $woItem in
                WOItemAccordionRow(
                    index: idx,
                    woId: draftWOId,
                    items: $viewModel.items,
                    expandedIndices: $expandedIndices,
                    showValidationNudge: $showValidationNudge,
                    onDelete: { indexToDelete in
                        handleDeleteWOItem(indexToDelete)
                    }
                )
                .id(woItem.id)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                )
            }

            // Add Item button
            Button {
                addNewItem()
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
    
    // MARK: - Toolbar Content
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        if viewModel.canCheckIn {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveWorkOrder {
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

    // MARK: - Sticky Check-In
    @ViewBuilder
    private func stickyCheckIn() -> some View {
        if viewModel.canCheckIn {
            VStack(spacing: 10) {
                Divider()
                    .padding(.top, 2)

                Button {
                    saveWorkOrder {
                        dismiss()
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
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        } else {
            EmptyView()
        }
    }

    // MARK: - Save Banner Overlay
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
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        if expandedIndices.isEmpty && !viewModel.items.isEmpty {
            expandedIndices.insert(0)
        }
    }
    
    private func handleCustomerSelection() {
        guard let newID = viewModel.selectedCustomer?.id else { return }
        print("✅ selectedCustomer changed → \(newID)")
    }
    
    private func selectCustomer(_ customer: Customer) {
        if viewModel.selectedCustomer?.id == customer.id {
            print("⚠️ selectCustomer: already selected, skipping redundant update.")
            return
        }

        withTransaction(Transaction(animation: .none)) {
            viewModel.selectedCustomer = customer
            customerSearch.resetSearch()
        }

        print("✅ selectCustomer:", customer.id.uuidString, customer.name, customer.phone)
    }

    private func addNewItem() {
        print("➕ ITEM: Adding new item (current: \(viewModel.items.count))")
        
        showValidationNudge = false
        
        withAnimation {
            viewModel.addItem()
            expandedIndices.insert(viewModel.items.indices.last!)
        }
        
        print("✅ ITEM: Added new item (total: \(viewModel.items.count))")
    }
    
    private func saveWorkOrder(onSuccess: (() -> Void)? = nil) {
        Task {
            await viewModel.saveWorkOrder()
            
            if !viewModel.showError {
                // Success
                savedWONumber = viewModel.workOrderNumber
                            showSaveBanner = true
                            draftWOId = UUID().uuidString
                            onSuccess?()

                // Reset form
                await viewModel.resetForm()
                expandedIndices = [0]
            }
        }
    }
    
    private func handleDeleteWOItem(_ index: Int) {
        if viewModel.items.count > 1 {
            withAnimation {
                viewModel.removeItem(at: index)
            }
            
            // Keep expansion on a sensible neighbor
            if expandedIndices.contains(index) {
                expandedIndices.remove(index)
                if viewModel.items.count > 0 {
                    expandedIndices.insert(max(0, min(index, viewModel.items.count - 1)))
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
            withAnimation {
                viewModel.items[0] = WO_Item.blank()
            }
            expandedIndices = [0]
        }
    }
}

// MARK: - Preview
#Preview {
    NewWorkOrderView()
        .environmentObject(AppState.shared)
}
