import SwiftUI
import Combine

@MainActor
class StateManagementService: ObservableObject {
    // MARK: - Singleton
    static let shared = StateManagementService()
    
    // MARK: - Published Properties
    @Published var currentWorkOrder: WorkOrder?
    @Published var selectedCustomer: Customer?
    @Published var isOffline = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var pendingChanges: [PendingChange] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NetworkMonitor.shared
    private let workOrdersDB = WorkOrdersDatabase.shared
    
    // MARK: - Initialization
    private init() {
        setupBindings()
        setupNetworkMonitoring()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor network status changes
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                self?.handleNetworkStatusChange(isConnected)
            }
            .store(in: &cancellables)
        
        // Monitor sync status
        $syncStatus
            .sink { [weak self] status in
                self?.handleSyncStatusChange(status)
            }
            .store(in: &cancellables)
    }
    
    private func setupNetworkMonitoring() {
        // Start monitoring network connectivity
        networkMonitor.startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Set the current work order being viewed/edited
    func setCurrentWorkOrder(_ workOrder: WorkOrder?) {
        currentWorkOrder = workOrder
    }
    
    /// Set the selected customer for new work orders
    func setSelectedCustomer(_ customer: Customer?) {
        selectedCustomer = customer
    }
    
    /// Add a pending change to be synced when online
    func addPendingChange(_ change: PendingChange) {
        pendingChanges.append(change)
        syncStatus = .pending
    }
    
    /// Remove a pending change after successful sync
    func removePendingChange(_ changeId: UUID) {
        pendingChanges.removeAll { $0.id == changeId }
        
        if pendingChanges.isEmpty {
            syncStatus = .idle
        }
    }
    
    /// Process all pending changes when back online
    func processPendingChanges() async {
        guard !pendingChanges.isEmpty else { return }
        
        syncStatus = .syncing
        
        for change in pendingChanges {
            do {
                try await processChange(change)
                removePendingChange(change.id)
            } catch {
                print("Failed to process pending change: \(error)")
                // Keep the change in pending list for retry
            }
        }
        
        syncStatus = .idle
    }
    
    /// Clear all state (useful for logout or app reset)
    func clearState() {
        currentWorkOrder = nil
        selectedCustomer = nil
        pendingChanges.removeAll()
        syncStatus = .idle
    }
    
    /// Validate current state consistency
    func validateState() -> StateValidationResult {
        var issues: [String] = []
        
        // Check for orphaned pending changes
        if !pendingChanges.isEmpty && !isOffline {
            issues.append("Found pending changes while online")
        }
        
        // Check for invalid work order state
        if let workOrder = currentWorkOrder {
            let validation = ValidationService.shared.validateWorkOrder(workOrder)
            if !validation.isValid {
                issues.append("Current work order has validation issues: \(validation.errorMessage ?? "")")
            }
        }
        
        return StateValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
    
    // MARK: - Private Methods
    
    private func handleNetworkStatusChange(_ isConnected: Bool) {
        isOffline = !isConnected
        
        if isConnected && !pendingChanges.isEmpty {
            Task {
                await processPendingChanges()
            }
        }
    }
    
    private func handleSyncStatusChange(_ status: SyncStatus) {
        switch status {
        case .syncing:
            // Could show sync indicator
            break
        case .error(let message):
            print("Sync error: \(message)")
        default:
            break
        }
    }
    
    private func processChange(_ change: PendingChange) async throws {
        switch change.type {
        case .createWorkOrder(let workOrder):
            try await workOrdersDB.addWorkOrder(workOrder)
            
        case .updateWorkOrder(let workOrder):
            try await workOrdersDB.updateWorkOrder(workOrder)
            
        case .deleteWorkOrder(let workOrderId):
            try await workOrdersDB.deleteWorkOrder(workOrderId)
            
        case .addNote(let workOrderId, let itemId, let note):
            // Handle note addition
            break
            
        case .updateStatus(let workOrderId, let itemId, let status):
            // Handle status update
            break
        }
    }
}

// MARK: - Supporting Types

enum SyncStatus: Equatable {
    case idle
    case pending
    case syncing
    case error(String)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.pending, .pending), (.syncing, .syncing):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

struct PendingChange: Identifiable {
    let id = UUID()
    let type: PendingChangeType
    let timestamp = Date()
    let retryCount: Int = 0
}

enum PendingChangeType {
    case createWorkOrder(WorkOrder)
    case updateWorkOrder(WorkOrder)
    case deleteWorkOrder(String)
    case addNote(String, UUID, WO_Note)
    case updateStatus(String, UUID, WorkOrderStatus)
}

struct StateValidationResult {
    let isValid: Bool
    let issues: [String]
    
    var issueMessage: String? {
        guard !issues.isEmpty else { return nil }
        return issues.joined(separator: "\n")
    }
}

// MARK: - State Management Extensions

extension StateManagementService {
    /// Get the current user context (for audit trails)
    func getCurrentUser() -> String {
        // TODO: Get from authentication service
        return "current_user"
    }
    
    /// Check if a work order is currently being edited
    func isWorkOrderBeingEdited(_ workOrderId: String) -> Bool {
        return currentWorkOrder?.id == workOrderId
    }
    
    /// Get the current app context
    func getCurrentContext() -> AppContext {
        return AppContext(
            currentWorkOrder: currentWorkOrder,
            selectedCustomer: selectedCustomer,
            isOffline: isOffline,
            syncStatus: syncStatus,
            pendingChangesCount: pendingChanges.count
        )
    }
}

struct AppContext {
    let currentWorkOrder: WorkOrder?
    let selectedCustomer: Customer?
    let isOffline: Bool
    let syncStatus: SyncStatus
    let pendingChangesCount: Int
    
    var hasActiveWorkOrder: Bool {
        currentWorkOrder != nil
    }
    
    var hasSelectedCustomer: Bool {
        selectedCustomer != nil
    }
    
    var needsSync: Bool {
        pendingChangesCount > 0 && !isOffline
    }
}
