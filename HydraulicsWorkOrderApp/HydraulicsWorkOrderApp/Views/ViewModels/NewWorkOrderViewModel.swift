import SwiftUI
import Combine
import FirebaseFirestore

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
    
    // MARK: - Computed Properties
    var workOrderNumber: String {
        WorkOrderNumberGenerator.generateWorkOrderNumber()
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
        // Type can live in item.type or dropdowns["type"] depending on caller
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
        // Monitor changes to determine if work order can be checked in
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
                !item.type.isEmpty && 
                !item.imageUrls.isEmpty && 
                !item.reasonsForService.isEmpty
            }
        }
        .assign(to: &$canCheckIn)
    }
    
    // MARK: - Public Methods
    
    /// Add a new blank item to the work order
    func addItem() {
        let newItem = WO_Item.blank()
        items.append(newItem)
    }
    
    /// Remove an item at the specified index
    func removeItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        items.remove(at: index)
        
        // Ensure we always have at least one item
        if items.isEmpty {
            addInitialItem()
        }
    }
    
    /// Update an item at the specified index
    func updateItem(_ item: WO_Item, at index: Int) {
        guard index >= 0 && index < items.count else { return }
        items[index] = item
    }
    
    /// Save the work order to Firebase
    func saveWorkOrder() async {
        // ───── Required Field Validation ─────
        guard let customer = selectedCustomer else {
            setError("Please select or add a Customer before saving this WorkOrder.")
            return
        }
        
        // ───── Discard Blank Items; Block on Partials ─────
        // 1) Drop items with neither type nor photo (true blanks)
        let nonBlankItems = items.filter { !isBlankItem($0) }
        
        // 2) If any partially filled item remains, bump user to finish it
        if let firstPartialIdx = nonBlankItems.firstIndex(where: { isPartiallyFilledItem($0) }) {
            setError("Please finish the highlighted WO_Item. Each item needs a Type and at least one Photo.")
            return
        }
        
        // 3) Must have at least one complete item to proceed
        guard !nonBlankItems.isEmpty, nonBlankItems.contains(where: { isCompleteItem($0) }) else {
            setError("Add at least one WO_Item with a Type and Photo before checking in.")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // ───── DEBUG LOG ─────
            print("🔍 SAVING: Starting work order save")
            print("Customer: \(customer.name) – \(customer.phone)")
            print("WO_Items count: \(items.count)")
            for (i, item) in items.enumerated() {
                print("  Item[\(i)] id=\(item.id) type=\(item.type) " +
                      "thumbs=\(item.thumbUrls.count) images=\(item.imageUrls.count)")
            }
            
            // ───── Snapshot items to avoid mutation during iteration ─────
            let itemsSnapshot = nonBlankItems
            let builtItems: [WO_Item] = itemsSnapshot.map { $0 }
            
            // ───── Build WorkOrder (ALL required fields) ─────
            let workOrder = WorkOrder(
                id: nil,                                   // @DocumentID → Firestore assigns; don't seed this
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
            
            // ───── Persist via WorkOrdersDatabase ─────
            #if DEBUG
            print("🚀 Attempting to save WorkOrder: \(workOrder.WO_Number)")
            #endif
            
            try await workOrdersDB.addWorkOrder(workOrder)
            
            #if DEBUG
            print("✅ WorkOrder saved successfully: \(workOrder.WO_Number)")
            #endif
            
        } catch {
            setError("Failed to save work order: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Reset the form to initial state
    func resetForm() async {
        selectedCustomer = nil
        items.removeAll()
        addInitialItem()
        errorMessage = nil
        showError = false
    }
    
    // MARK: - Private Methods
    
    private func addInitialItem() {
        if items.isEmpty {
            items.append(WO_Item())
        }
    }
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Validation Extensions
extension NewWorkOrderViewModel {
    func validateItem(_ item: WO_Item) -> [String] {
        var errors: [String] = []
        
        if item.type.isEmpty {
            errors.append("Type is required")
        }
        
        if item.imageUrls.isEmpty {
            errors.append("At least one image is required")
        }
        
        if item.reasonsForService.isEmpty {
            errors.append("At least one reason for service is required")
        }
        
        return errors
    }
    
    func getItemValidationErrors(for index: Int) -> [String] {
        guard index >= 0 && index < items.count else { return [] }
        return validateItem(items[index])
    }
}
