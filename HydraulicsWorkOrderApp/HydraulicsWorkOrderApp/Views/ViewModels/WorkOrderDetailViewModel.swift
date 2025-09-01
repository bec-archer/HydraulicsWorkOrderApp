import SwiftUI
import Combine
import FirebaseFirestore

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
    
    // MARK: - Computed Properties
    var customerName: String {
        workOrder.customer.name
    }
    
    var customerCompany: String? {
        workOrder.customer.company
    }
    
    var customerEmail: String? {
        workOrder.customer.email
    }
    
    var customerPhone: String {
        workOrder.customer.phone
    }
    
    var isTaxExempt: Bool {
        workOrder.customer.isTaxExempt
    }
    
    var currentStatus: WO_Status {
        workOrder.statusHistory.last ?? WO_Status(status: .checkedIn, timestamp: workOrder.createdDate, note: "Work order checked in")
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
                      let woId = notification.object as? String,
                      let woNumber = notification.userInfo?["WO_Number"] as? String,
                      woNumber == self.workOrder.WO_Number else { return }
                
                // Update the work order from the database
                Task { @MainActor in
                    await self.refreshWorkOrder()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Update the status of a specific item
    func updateItemStatus(_ status: WorkOrderStatus, for itemIndex: Int, note: String? = nil) async {
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
                timestamp: Date(),
                note: note ?? "Status updated to \(status.rawValue)",
                itemId: workOrder.items[itemIndex].id
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
                text: noteText,
                timestamp: Date(),
                author: "current_user", // TODO: Get from auth
                imageURL: imageURL
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
        
        print("🔄 WorkOrderDetailViewModel: Starting refresh for \(workOrder.WO_Number)")
        
        do {
            let updatedWorkOrder = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorkOrder, Error>) in
                workOrdersDB.fetchWorkOrder(woId: workOrder.id ?? "") { result in
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
                print("🔄 WorkOrderDetailViewModel: Refreshed work order \(workOrder.WO_Number)")
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
    
    // MARK: - Private Methods
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Helper Extensions
extension WorkOrderDetailViewModel {
    func getStatusColor(_ status: WorkOrderStatus) -> Color {
        switch status {
        case .checkedIn:
            return .blue
        case .disassembly:
            return .teal
        case .inProgress:
            return .yellow
        case .testFailed:
            return .red
        case .complete:
            return .green
        case .closed:
            return .gray
        }
    }
    
    func getStatusDisplayName(_ status: WorkOrderStatus) -> String {
        switch status {
        case .checkedIn:
            return "Checked In"
        case .disassembly:
            return "Disassembly"
        case .inProgress:
            return "In Progress"
        case .testFailed:
            return "Test Failed"
        case .complete:
            return "Complete"
        case .closed:
            return "Closed"
        }
    }
}
