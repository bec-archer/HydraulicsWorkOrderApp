import SwiftUI
import Combine
import FirebaseAuth
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
        print("🔍 DEBUG: updateItemStatus called with status: '\(status)', itemIndex: \(itemIndex)")
        guard itemIndex >= 0 && itemIndex < workOrder.items.count else {
            print("❌ DEBUG: Invalid item index: \(itemIndex), total items: \(workOrder.items.count)")
            setError("Invalid item index")
            return
        }
        
        errorMessage = nil
        
        do {
            // Create new status entry
            let newStatus = WO_Status(
                status: status,
                user: getCurrentUser(),
                timestamp: Date(),
                notes: note ?? "Status updated to \(status)"
            )
            
            print("🔍 DEBUG: Created new status: '\(newStatus.status)'")
            
            // Update the work order
            workOrder.items[itemIndex].statusHistory.append(newStatus)
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = getCurrentUser()
            
            print("🔍 DEBUG: Added status to history. Total statuses now: \(workOrder.items[itemIndex].statusHistory.count)")
            
            // Save to Firebase
            print("🔍 DEBUG: Saving to Firebase...")
            try await workOrdersDB.updateWorkOrder(workOrder)
            print("✅ DEBUG: Successfully saved to Firebase")
            
        } catch {
            print("❌ DEBUG: Failed to save to Firebase: \(error)")
            setError("Failed to update status: \(error.localizedDescription)")
        }
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
            workOrder.lastModifiedBy = getCurrentUser()
            
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
            workOrder.lastModifiedBy = getCurrentUser()
            
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
            workOrder.lastModifiedBy = getCurrentUser()
            
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
            workOrder.lastModifiedBy = getCurrentUser()
            
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
            workOrder.lastModifiedBy = getCurrentUser()
            
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
            workOrder.lastModifiedBy = getCurrentUser()
            
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
    
    
    func toggleServicePerformedStatus(for itemIndex: Int, reason: String) async {
        print("🔍 DEBUG: toggleServicePerformedStatus called for itemIndex: \(itemIndex), reason: '\(reason)'")
        guard itemIndex >= 0 && itemIndex < workOrder.items.count else {
            print("❌ DEBUG: Invalid item index: \(itemIndex), total items: \(workOrder.items.count)")
            setError("Invalid item index")
            return
        }
        
        var item = workOrder.items[itemIndex]
        let isCurrentlyPerformed = item.completedReasons.contains(reason)
        let currentUser = getCurrentUser()
        let currentTime = Date()
        
        if isCurrentlyPerformed {
            print("🔍 DEBUG: Reason is currently performed, removing from completedReasons")
            item.completedReasons.removeAll { $0 == reason }
            
            // Add note about unchecking
            let note = WO_Note(
                workOrderId: workOrder.id,
                itemId: item.id.uuidString,
                user: currentUser,
                text: "❌ • \(reason)",
                timestamp: currentTime
            )
            item.notes.append(note)
            
            // Remove the "Service Performed" status entry from history
            let statusText = "Service Performed — \(reason)"
            item.statusHistory.removeAll { status in
                status.status == statusText
            }
            
        } else {
            print("🔍 DEBUG: Reason is not performed, adding to completedReasons")
            item.completedReasons.append(reason)
            
            // Add note about checking
            let note = WO_Note(
                workOrderId: workOrder.id,
                itemId: item.id.uuidString,
                user: currentUser,
                text: "✅ • \(reason)",
                timestamp: currentTime
            )
            item.notes.append(note)
            
            // Add status entry to history for tracking
            let statusEntry = WO_Status(
                status: "Service Performed — \(reason)",
                user: currentUser,
                timestamp: currentTime
            )
            item.statusHistory.append(statusEntry)
        }
        
        // Update the item in the work order
        workOrder.items[itemIndex] = item
        workOrder.lastModified = currentTime
        workOrder.lastModifiedBy = currentUser
        
        // Save to database
        do {
            try await workOrdersDB.updateWorkOrder(workOrder)
        } catch {
            print("❌ DEBUG: Failed to save work order: \(error)")
            setError("Failed to save work order: \(error.localizedDescription)")
        }
    }
    
    
    /// Update the work order with fresh data from Firebase
    func updateWorkOrder(_ freshWorkOrder: WorkOrder) {
        // Update the work order
        workOrder = freshWorkOrder
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    /// Add a note with images to a specific item
    func addItemNoteWithImages(_ noteText: String, images: [UIImage], to itemIndex: Int) async {
        print("🔍 DEBUG: addItemNoteWithImages called for itemIndex: \(itemIndex), note: '\(noteText)', images: \(images.count)")
        guard itemIndex >= 0 && itemIndex < workOrder.items.count else {
            print("❌ DEBUG: Invalid item index: \(itemIndex), total items: \(workOrder.items.count)")
            setError("Invalid item index")
            return
        }
        
        errorMessage = nil
        
        do {
            // Get current user
            let currentUser = getCurrentUser()
            print("🔍 DEBUG: Current user: \(currentUser)")
            
            // Create new note
            let newNote = WO_Note(
                workOrderId: workOrder.id,
                itemId: workOrder.items[itemIndex].id.uuidString,
                user: currentUser,
                text: noteText,
                timestamp: Date(),
                imageUrls: [] // Will be populated after image upload
            )
            
            print("🔍 DEBUG: Created new note: '\(newNote.text)'")
            
            // Upload images if any
            var imageUrls: [String] = []
            var thumbnailUrls: [String] = []
            if !images.isEmpty {
                print("🔍 DEBUG: Uploading \(images.count) images...")
                do {
                    // Use the existing ImageManagementService to upload images
                    let result = try await ImageManagementService.shared.uploadImages(images, for: workOrder.id, itemId: workOrder.items[itemIndex].id)
                    imageUrls = result.imageURLs
                    thumbnailUrls = result.thumbnailURLs
                    print("🔍 DEBUG: Successfully uploaded \(imageUrls.count) images and \(thumbnailUrls.count) thumbnails")
                } catch {
                    print("❌ DEBUG: Failed to upload images: \(error)")
                    setError("Failed to upload images: \(error.localizedDescription)")
                    return
                }
            }
            
            print("🔍 DEBUG: Image URLs: \(imageUrls)")
            print("🔍 DEBUG: Thumbnail URLs: \(thumbnailUrls)")
            
            // Update note with thumbnail URLs (for display in notes list)
            let finalNote = WO_Note(
                id: newNote.id,
                workOrderId: newNote.workOrderId,
                itemId: newNote.itemId,
                user: newNote.user,
                text: newNote.text,
                timestamp: newNote.timestamp,
                imageUrls: thumbnailUrls
            )
            
            // Add note to item
            workOrder.items[itemIndex].notes.append(finalNote)
            
            // Add images to item's image arrays (append to end to maintain order)
            for imageUrl in imageUrls {
                workOrder.items[itemIndex].imageUrls.append(imageUrl)
            }
            
            // Add thumbnail URLs to item's thumbnail array (append to end to maintain order)
            for thumbnailUrl in thumbnailUrls {
                workOrder.items[itemIndex].thumbUrls.append(thumbnailUrl)
            }
            
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = currentUser
            
            print("🔍 DEBUG: Added note to item. Total notes now: \(workOrder.items[itemIndex].notes.count)")
            print("🔍 DEBUG: Added \(imageUrls.count) images to item. Total images now: \(workOrder.items[itemIndex].imageUrls.count)")
            
            // Save to Firebase
            print("🔍 DEBUG: Saving to Firebase...")
            try await workOrdersDB.updateWorkOrder(workOrder)
            print("✅ DEBUG: Successfully saved to Firebase")
            
        } catch {
            print("❌ DEBUG: Failed to save note: \(error)")
            setError("Failed to add note: \(error.localizedDescription)")
        }
    }
    
    /// Get the current user for attribution
    private func getCurrentUser() -> String {
        // Get current user from AppState
        let currentUser = AppState.shared.currentUser
        if let user = currentUser {
            return user.displayName
        } else {
            // Fallback to Firebase Auth if available
            if let firebaseUser = Auth.auth().currentUser {
                return firebaseUser.displayName ?? firebaseUser.email ?? "Unknown User"
            } else {
                return "Unknown User"
            }
        }
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
