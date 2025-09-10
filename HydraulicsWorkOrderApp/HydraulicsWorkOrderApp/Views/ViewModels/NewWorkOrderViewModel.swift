import SwiftUI
import Combine
import Foundation

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
    private let imageService = ImageManagementService.shared
    private let validationService = ValidationService.shared
    private let stateService = StateManagementService.shared
    private let versionService = DropdownVersionService.shared
    
    // MARK: - Computed Properties
    var workOrderNumber: String {
        WorkOrderNumberGenerator.generateWorkOrderNumber()
    }
    
    var hasValidCustomer: Bool {
        selectedCustomer != nil
    }
    
    var hasValidItems: Bool {
        let nonBlankItems = items.filter { !isBlankItem($0) }
        print("🔍 DEBUG: hasValidItems check - Total items: \(items.count), Non-blank: \(nonBlankItems.count)")
        
        let isValid = !nonBlankItems.isEmpty && nonBlankItems.allSatisfy { item in
            let validation = validationService.validateItem(item)
            print("🔍 DEBUG: Item \(item.id) validation: \(validation.isValid ? "✅" : "❌") - \(validation.errors)")
            return validation.isValid
        }
        
        print("🔍 DEBUG: hasValidItems result: \(isValid ? "✅ VALID" : "❌ INVALID")")
        return isValid
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
        print("🔍 DEBUG: NewWorkOrderViewModel initializing")
        setupBindings()
        addInitialItem()
        print("🔍 DEBUG: NewWorkOrderViewModel initialized with \(items.count) items")
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
    
    /// Add initial blank item when view model is created
    private func addInitialItem() {
        print("🔍 DEBUG: addInitialItem called, items.count = \(items.count)")
        if items.isEmpty {
            print("🔍 DEBUG: Adding initial item")
            addItem()
            print("🔍 DEBUG: After adding initial item, items.count = \(items.count)")
        } else {
            print("🔍 DEBUG: Items already exist, skipping initial item")
        }
    }
    
    // MARK: - Public Methods
    
    /// Add a new blank item to the work order
    func addItem() {
        var newItem = WO_Item.create()
        newItem.dropdownSchemaVersion = DropdownSchema.currentVersion
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
    
    // MARK: - Image Management
    
    /// Upload images for a specific item
    func uploadImages(_ images: [UIImage], for itemIndex: Int) async {
        guard itemIndex >= 0 && itemIndex < items.count else { return }
        
        do {
            let workOrderId = UUID().uuidString // Generate temporary ID
            let itemId = items[itemIndex].id
            
            var uploadedURLs: [String] = []
            var uploadedThumbURLs: [String] = []
            
            for image in images {
                let imageURL = try await imageService.uploadSingleImage(image, for: workOrderId, itemId: itemId)
                uploadedURLs.append(imageURL)
            }
            
            // Get thumbnail URLs after all images are uploaded
            uploadedThumbURLs = try await imageService.getThumbnailURLs(for: workOrderId, itemId: itemId)
            
            // Update the item with uploaded URLs
            items[itemIndex].imageUrls.append(contentsOf: uploadedURLs)
            items[itemIndex].thumbUrls.append(contentsOf: uploadedThumbURLs)
            
        } catch {
            setError("Failed to upload images: \(error.localizedDescription)")
        }
    }
    
    /// Delete an image from a specific item
    func deleteImage(_ imageURL: String, from itemIndex: Int) async {
        guard itemIndex >= 0 && itemIndex < items.count else { return }
        
        do {
            try await imageService.deleteImage(imageURL)
            
            // Remove from local arrays
            items[itemIndex].imageUrls.removeAll { $0 == imageURL }
            items[itemIndex].thumbUrls.removeAll { $0 == imageURL }
            
        } catch {
            setError("Failed to delete image: \(error.localizedDescription)")
        }
    }
    
    /// Save the work order to Core Data
    func saveWorkOrder() async {
        print("🔍 DEBUG: saveWorkOrder() called")
        
        // ───── Required Field Validation ─────
        guard let customer = selectedCustomer else {
            print("❌ DEBUG: No customer selected")
            setError("Please select or add a Customer before saving this WorkOrder.")
            return
        }
        
        print("🔍 DEBUG: Customer selected: \(customer.name) (ID: \(customer.id))")
        
        // ───── Use ValidationService for comprehensive validation ─────
        let nonBlankItems = items.filter { !isBlankItem($0) }
        print("🔍 DEBUG: Total items: \(items.count), Non-blank items: \(nonBlankItems.count)")
        
        // Debug each item
        for (index, item) in nonBlankItems.enumerated() {
            print("🔍 DEBUG: Item[\(index)] validation:")
            print("  - ID: \(item.id)")
            print("  - Type: '\(item.type)'")
            print("  - Image URLs: \(item.imageUrls.count) items")
            print("  - Thumb URLs: \(item.thumbUrls.count) items")
            print("  - Reasons: \(item.reasonsForService.count) items")
            print("  - Asset Tag: '\(item.assetTagId ?? "nil")'")
            
            // Check individual item validation
            let itemValidation = validationService.validateItem(item, at: index)
            print("  - Item validation: \(itemValidation.isValid ? "✅ VALID" : "❌ INVALID")")
            if !itemValidation.isValid {
                print("  - Validation errors: \(itemValidation.errors)")
            }
        }
        
        // Validate customer
        print("🔍 DEBUG: Validating customer...")
        let customerValidation = validationService.validateCustomer(customer)
        print("🔍 DEBUG: Customer validation: \(customerValidation.isValid ? "✅ VALID" : "❌ INVALID")")
        if !customerValidation.isValid {
            print("❌ DEBUG: Customer validation errors: \(customerValidation.errors)")
            setError("Customer validation failed: \(customerValidation.errors.joined(separator: ", "))")
            return
        }
        
        // Validate items
        print("🔍 DEBUG: Validating all items...")
        let itemsValidation = validationService.validateItems(nonBlankItems)
        print("🔍 DEBUG: Items validation: \(itemsValidation.isValid ? "✅ VALID" : "❌ INVALID")")
        if !itemsValidation.isValid {
            print("❌ DEBUG: Items validation errors: \(itemsValidation.errors)")
            setError("Item validation failed: \(itemsValidation.errors.joined(separator: ", "))")
            return
        }
        
        // Must have at least one complete item to proceed
        guard !nonBlankItems.isEmpty else {
            setError("Add at least one WO_Item with a Type and Photo before checking in.")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // ───── DEBUG LOG ─────
            print("🔍 SAVING: Starting work order save")
            print("Customer: \(customer.name) – \(customer.phoneNumber)")
            print("WO_Items count: \(items.count)")
            for (i, item) in items.enumerated() {
                print("  Item[\(i)] id=\(item.id) type=\(item.type) " +
                      "thumbs=\(item.thumbUrls.count) images=\(item.imageUrls.count)")
            }
            
            // ───── Snapshot items to avoid mutation during iteration ─────
            let itemsSnapshot = nonBlankItems
            let builtItems: [WO_Item] = itemsSnapshot.map { $0 }
            
            #if DEBUG
            print("🔍 BUILDING: WorkOrder with \(builtItems.count) items")
            for (i, item) in builtItems.enumerated() {
                print("  Built Item[\(i)]: type='\(item.type)', dropdowns[type]='\(item.dropdowns["type"] ?? "nil")'")
                print("    imageUrls: \(item.imageUrls), thumbUrls: \(item.thumbUrls)")
                print("    reasons: \(item.reasonsForService)")
                print("    dropdowns: \(item.dropdowns)")
                print("    statusHistory: \(item.statusHistory.count)")
                print("    notes: \(item.notes.count)")
            }
            #endif
            
            // ───── Build WorkOrder (ALL required fields) ─────
            print("🔍 DEBUG: Building WorkOrder with \(builtItems.count) items")
            let workOrder = WorkOrder(
                id: UUID().uuidString,                    // Generate new UUID for Core Data
                createdBy: "Tech",
                customerId: customer.id.uuidString,
                customerName: customer.name,
                customerCompany: customer.company,
                customerEmail: customer.email,
                customerTaxExempt: customer.taxExempt,
                customerPhone: customer.phoneNumber,       // Updated to use phoneNumber
                customerEmojiTag: customer.emojiTag,      // Include customer emoji tag
                workOrderType: "Intake",                  // Updated field name
                primaryImageURL: nil,                     // Will be set when images are uploaded
                timestamp: Date(),
                status: "Checked In",
                workOrderNumber: workOrderNumber,         // Updated field name
                flagged: false,
                assetTagId: nil,
                estimatedCost: nil,
                finalCost: nil,
                dropdowns: [:],
                dropdownSchemaVersion: 1,
                lastModified: Date(),
                lastModifiedBy: "Tech",
                tagBypassReason: nil,
                isDeleted: false,
                syncStatus: "pending",                    // Mark as pending sync
                lastSyncDate: nil,                        // No sync date yet
                notes: [],
                items: builtItems
            )
            
            // ───── Persist via WorkOrdersDatabase ─────
            print("🚀 DEBUG: Attempting to save WorkOrder: \(workOrder.workOrderNumber)")
            print("🔍 DEBUG: WorkOrder details:")
            print("  - ID: \(workOrder.id)")
            print("  - Customer: \(workOrder.customerName)")
            print("  - Items count: \(workOrder.items.count)")
            print("  - Status: \(workOrder.status)")
            
            // Debug each item in the work order
            for (index, item) in workOrder.items.enumerated() {
                print("🔍 DEBUG: WorkOrder Item[\(index)]:")
                print("  - ID: \(item.id)")
                print("  - Type: '\(item.type)'")
                print("  - Image URLs: \(item.imageUrls.count)")
                print("  - Thumb URLs: \(item.thumbUrls.count)")
                print("  - Asset Tag: '\(item.assetTagId ?? "nil")'")
            }
            
            try await workOrdersDB.addWorkOrder(workOrder)
            
            print("✅ DEBUG: WorkOrder saved successfully: \(workOrder.workOrderNumber)")
            
        } catch {
            print("❌ DEBUG: Error saving work order: \(error)")
            print("❌ DEBUG: Error localized description: \(error.localizedDescription)")
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
