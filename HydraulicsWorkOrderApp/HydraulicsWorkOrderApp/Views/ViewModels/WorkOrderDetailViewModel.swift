import SwiftUI
import Combine
import FirebaseFirestore
import Foundation

@MainActor
class WorkOrderDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var workOrder: WorkOrder
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showAddNoteSheet = false
    @Published var showStatusPickerSheet = false
    @Published var selectedItemIndex: Int?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let workOrdersDB = WorkOrdersDatabase.shared
    private let imageService = ImageManagementService.shared
    private let validationService = ValidationService.shared
    private let stateService = StateManagementService.shared
    
    // MARK: - Computed Properties
    var customerName: String {
        workOrder.customerName
    }
    
    var customerCompany: String? {
        workOrder.customerCompany
    }
    
    var customerEmail: String? {
        workOrder.customerEmail
    }
    
    var customerPhone: String {
        workOrder.customerPhone
    }
    
    var isTaxExempt: Bool {
        workOrder.customerTaxExempt
    }
    
    var currentStatus: String {
        workOrder.status
    }
    
    // MARK: - Initialization
    init(workOrder: WorkOrder) {
        self.workOrder = workOrder
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor work order changes for validation
        $workOrder
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Listen for work order updates from the database
        NotificationCenter.default.publisher(for: .WorkOrderSaved)
            .sink { [weak self] notification in
                guard let self = self,
                      let _ = notification.object as? String,
                      let woNumber = notification.userInfo?["WO_Number"] as? String,
                      woNumber == self.workOrder.workOrderNumber else { return }
                
                // Update the work order from the database
                Task { @MainActor in
                    await self.refreshWorkOrder()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Update the status of a specific item
    func updateItemStatus(_ status: String, for itemIndex: Int, note: String? = nil) async {
        guard itemIndex >= 0 && itemIndex < workOrder.items.count else {
            setError("Invalid item index")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create new status entry
            let newStatus = WO_Status(
                status: status,
                user: "current_user", // TODO: Get from auth
                timestamp: Date(),
                notes: note ?? "Status updated to \(status)"
            )
            
            // Update the work order
            workOrder.items[itemIndex].statusHistory.append(newStatus)
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "current_user" // TODO: Get from auth
            
            // Save to Firebase
            try await workOrdersDB.updateWorkOrder(workOrder)
            
        } catch {
            setError("Failed to update status: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Add a note to a specific item
    func addNote(_ noteText: String, imageURL: String? = nil, to itemIndex: Int) async {
        guard itemIndex >= 0 && itemIndex < workOrder.items.count else {
            setError("Invalid item index")
            return
        }
        
        guard !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setError("Note text cannot be empty")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newNote = WO_Note(
                workOrderId: workOrder.id,
                itemId: workOrder.items[itemIndex].id.uuidString,
                user: "current_user",
                text: noteText,
                timestamp: Date(),
                imageUrls: imageURL != nil ? [imageURL!] : []
            )
            
            // Add note to the item
            workOrder.items[itemIndex].notes.append(newNote)
            
            // Add image to item if provided
            if let imageURL = imageURL {
                workOrder.items[itemIndex].imageUrls.append(imageURL)
            }
            
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "current_user" // TODO: Get from auth
            
            // Save to Firebase
            try await workOrdersDB.updateWorkOrder(workOrder)
            
        } catch {
            setError("Failed to add note: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Toggle completion of a reason for service
    func toggleReasonCompletion(_ reason: String, for itemIndex: Int) async {
        guard itemIndex >= 0 && itemIndex < workOrder.items.count else {
            setError("Invalid item index")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var item = workOrder.items[itemIndex]
            
            if item.completedReasons.contains(reason) {
                item.completedReasons.removeAll { $0 == reason }
            } else {
                item.completedReasons.append(reason)
            }
            
            workOrder.items[itemIndex] = item
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "current_user" // TODO: Get from auth
            
            // Save to Firebase
            try await workOrdersDB.updateWorkOrder(workOrder)
            
        } catch {
            setError("Failed to update reason completion: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Refresh work order data from Firebase
    func refreshWorkOrder() async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 WorkOrderDetailViewModel: Starting refresh for \(workOrder.workOrderNumber)")
        
        do {
            let updatedWorkOrder = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorkOrder, Error>) in
                workOrdersDB.fetchWorkOrder(woId: workOrder.id) { result in
                    switch result {
                    case .success(let wo):
                        continuation.resume(returning: wo)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            await MainActor.run {
                let oldImageCount = self.workOrder.items.first?.imageUrls.count ?? 0
                let newImageCount = updatedWorkOrder.items.first?.imageUrls.count ?? 0
                
                self.workOrder = updatedWorkOrder
                print("🔄 WorkOrderDetailViewModel: Refreshed work order \(workOrder.workOrderNumber)")
                print("  - Old image count: \(oldImageCount)")
                print("  - New image count: \(newImageCount)")
                print("  - Items updated: \(updatedWorkOrder.items.count)")
            }
        } catch {
            print("❌ WorkOrderDetailViewModel: Failed to refresh work order: \(error)")
            setError("Failed to refresh work order: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Get the display text for "Other" reason notes
    func getOtherReasonDisplayText(for item: WO_Item) -> String? {
        guard let reasonNotes = item.reasonNotes, !reasonNotes.isEmpty else { return nil }
        return "✅ Other: \(reasonNotes)"
    }
    
    /// Check if a reason is completed for an item
    func isReasonCompleted(_ reason: String, for item: WO_Item) -> Bool {
        item.completedReasons.contains(reason)
    }
    
    /// Replace a tag for a work order item
    func replaceTag(_ replacement: TagReplacement, for item: WO_Item) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Find the item index
            guard let itemIndex = workOrder.items.firstIndex(where: { $0.id == item.id }) else {
                setError("Item not found in work order")
                return
            }
            
            // Update the item's tag ID
            workOrder.items[itemIndex].assetTagId = replacement.newTagId
            
            // Add the replacement to the history
            if workOrder.items[itemIndex].tagReplacementHistory == nil {
                workOrder.items[itemIndex].tagReplacementHistory = []
            }
            workOrder.items[itemIndex].tagReplacementHistory?.append(replacement)
            
            // Update last modified info
            workOrder.items[itemIndex].lastModified = Date()
            workOrder.items[itemIndex].lastModifiedBy = "current_user" // TODO: Get from auth
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "current_user" // TODO: Get from auth
            
            // Save to database
            try await workOrdersDB.updateWorkOrder(workOrder)
            
            print("✅ WorkOrderDetailViewModel: Tag replaced from '\(replacement.oldTagId)' to '\(replacement.newTagId)'")
            
        } catch {
            print("❌ WorkOrderDetailViewModel: Error replacing tag: \(error)")
            setError("Failed to replace tag: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Toggle the flagged status of the work order
    func toggleFlagged() async {
        isLoading = true
        errorMessage = nil
        
        do {
            workOrder.flagged.toggle()
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "current_user" // TODO: Get from auth
            
            try await workOrdersDB.updateWorkOrder(workOrder)
            
        } catch {
            setError("Failed to toggle flag: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Mark the work order as completed
    func markCompleted() async {
        isLoading = true
        errorMessage = nil
        
        do {
            workOrder.status = "Completed"
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "current_user" // TODO: Get from auth
            
            try await workOrdersDB.updateWorkOrder(workOrder)
            
        } catch {
            setError("Failed to mark as completed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Mark the work order as closed
    func markClosed() async {
        isLoading = true
        errorMessage = nil
        
        do {
            workOrder.status = "Closed"
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "current_user" // TODO: Get from auth
            
            try await workOrdersDB.updateWorkOrder(workOrder)
            
        } catch {
            setError("Failed to mark as closed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Delete the work order
    func deleteWorkOrder() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await workOrdersDB.deleteWorkOrder(workOrder.id)
            
        } catch {
            setError("Failed to delete work order: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Add a note to a specific item (simplified version)
    func addItemNote(_ note: WO_Note, to itemIndex: Int) async {
        await addNote(note.text, to: itemIndex)
    }
    
    // MARK: - Private Methods
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Helper Extensions
extension WorkOrderDetailViewModel {
    func getStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "checked in":
            return .blue
        case "disassembly":
            return .teal
        case "in progress":
            return .yellow
        case "test failed":
            return .red
        case "complete", "done":
            return .green
        case "closed":
            return .gray
        default:
            return .gray
        }
    }
    
    func getStatusDisplayName(_ status: String) -> String {
        switch status.lowercased() {
        case "checked in":
            return "Checked In"
        case "disassembly":
            return "Disassembly"
        case "in progress":
            return "In Progress"
        case "test failed":
            return "Test Failed"
        case "complete", "done":
            return "Complete"
        case "closed":
            return "Closed"
        default:
            return status
        }
    }
}
