import SwiftUI
import Combine

@MainActor
class ActiveWorkOrdersViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var workOrders: [WorkOrder] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let workOrdersDB = WorkOrdersDatabase.shared
    private let imageService = ImageManagementService.shared
    private let validationService = ValidationService.shared
    private let stateService = StateManagementService.shared
    
    // Cache for active work orders to prevent excessive recalculations
    private var cachedActiveWorkOrders: [WorkOrder]?
    private var lastWorkOrdersHash: Int = 0
    
    // Debouncing to prevent multiple simultaneous database calls
    private var loadWorkOrdersTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    var activeWorkOrders: [WorkOrder] {
        // Calculate hash of current work orders to detect changes
        let currentHash = workOrders.map { "\($0.id)-\($0.lastModified.timeIntervalSince1970)" }.joined().hashValue
        
        // Return cached result if work orders haven't changed
        if let cached = cachedActiveWorkOrders, currentHash == lastWorkOrdersHash {
            return cached
        }
        
        // Remove duplicates by WO_Number, keeping the most recent one
        var uniqueWorkOrders: [String: WorkOrder] = [:]
        var duplicatesFound: [String: Int] = [:]
        
        #if DEBUG
        print("🔍 DEBUG: Processing \(workOrders.count) work orders for deduplication")
        #endif
        
        for workOrder in workOrders {
            #if DEBUG
            print("🔍 DEBUG: Processing WO: \(workOrder.workOrderNumber) (ID: \(workOrder.id), Status: \(workOrder.status), Deleted: \(workOrder.isDeleted))")
            #endif
            
            if !workOrder.isDeleted && !workOrder.isClosed {
                // If we already have this WO_Number, keep the one with the most recent lastModified
                if let existing = uniqueWorkOrders[workOrder.workOrderNumber] {
                    duplicatesFound[workOrder.workOrderNumber, default: 1] += 1
                    #if DEBUG
                    print("⚠️ DEBUG: Duplicate WO_Number found: \(workOrder.workOrderNumber)")
                    print("  - Existing: ID=\(existing.id), LastModified=\(existing.lastModified)")
                    print("  - Current: ID=\(workOrder.id), LastModified=\(workOrder.lastModified)")
                    #endif
                    
                    // Prefer work orders with non-empty IDs, then most recent
                    let existingHasId = !existing.id.isEmpty
                    let currentHasId = !workOrder.id.isEmpty
                    
                    if currentHasId && !existingHasId {
                        // Current has ID, existing doesn't - prefer current
                        uniqueWorkOrders[workOrder.workOrderNumber] = workOrder
                        #if DEBUG
                        print("  - Keeping current (has ID)")
                        #endif
                    } else if !currentHasId && existingHasId {
                        // Existing has ID, current doesn't - keep existing
                        #if DEBUG
                        print("  - Keeping existing (has ID)")
                        #endif
                        // Do nothing
                    } else if workOrder.lastModified > existing.lastModified {
                        // Both have same ID status, prefer most recent
                        uniqueWorkOrders[workOrder.workOrderNumber] = workOrder
                        #if DEBUG
                        print("  - Keeping current (more recent)")
                        #endif
                    } else {
                        #if DEBUG
                        print("  - Keeping existing (more recent)")
                        #endif
                    }
                } else {
                    uniqueWorkOrders[workOrder.workOrderNumber] = workOrder
                    #if DEBUG
                    print("  - Adding new WO_Number")
                    #endif
                }
            } else {
                #if DEBUG
                print("  - Skipping (deleted or closed)")
                #endif
            }
        }
        
        #if DEBUG
        if !duplicatesFound.isEmpty {
            print("⚠️ DEBUG: Found duplicate work order numbers:")
            for (woNumber, count) in duplicatesFound {
                print("  - \(woNumber): \(count) duplicates")
            }
        }
        #endif
        
        let active = Array(uniqueWorkOrders.values)
            .sorted {
                if $0.flagged != $1.flagged { return $0.flagged && !$1.flagged }
                return $0.timestamp < $1.timestamp
            }
        
        #if DEBUG
        print("📋 ACTIVE: \(active.count) active work orders (total: \(workOrders.count))")
        #endif
        
        // Cache the result
        cachedActiveWorkOrders = active
        lastWorkOrdersHash = currentHash
        
        return active
    }
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadWorkOrders()
    }
    
    deinit {
        loadWorkOrdersTask?.cancel()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor work orders database changes
        workOrdersDB.$workOrders
            .sink { [weak self] workOrders in
                self?.workOrders = workOrders
            }
            .store(in: &cancellables)
        
        // Monitor state service for sync status
        stateService.$syncStatus
            .sink { [weak self] status in
                if status == .syncing {
                    self?.isLoading = true
                } else if status == .idle {
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load work orders from the database with debouncing
    func loadWorkOrders() {
        // Cancel any existing load task
        loadWorkOrdersTask?.cancel()
        
        // Create new debounced task
        loadWorkOrdersTask = Task {
            // Small delay to debounce rapid calls
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            #if DEBUG
            print("🔍 DEBUG: ActiveWorkOrdersViewModel.loadWorkOrders() called")
            #endif
            
            await MainActor.run {
                isLoading = true
                #if DEBUG
                print("🔍 DEBUG: Set isLoading = true")
                #endif
            }
            
            do {
                #if DEBUG
                print("🔍 DEBUG: Calling workOrdersDB.getAllWorkOrders()")
                #endif
                let workOrders = try await workOrdersDB.getAllWorkOrders()
                #if DEBUG
                print("🔍 DEBUG: Got \(workOrders.count) work orders from database")
                #endif
                
                await MainActor.run {
                    self.workOrders = workOrders
                    self.isLoading = false
                    #if DEBUG
                    print("📋 DEBUG: Loaded \(workOrders.count) work orders into viewModel")
                    
                    // Debug each work order
                    for (index, workOrder) in workOrders.enumerated() {
                        print("🔍 DEBUG: WorkOrder[\(index)]: \(workOrder.workOrderNumber) - \(workOrder.customerName) - \(workOrder.status)")
                    }
                    #endif
                }
            } catch {
                #if DEBUG
                print("❌ DEBUG: Error loading work orders: \(error)")
                print("❌ DEBUG: Error localized description: \(error.localizedDescription)")
                #endif
                await MainActor.run {
                    self.isLoading = false
                    self.setError("Failed to load work orders: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Refresh work orders from the database
    func refreshWorkOrders() {
        loadWorkOrders()
    }
    
    /// Delete a work order
    func deleteWorkOrder(_ workOrder: WorkOrder) {
        Task {
            do {
                // Validate before deletion
                let validation = validationService.validateWorkOrder(workOrder)
                if !validation.isValid {
                    await MainActor.run {
                        setError("Cannot delete work order: \(validation.errors.joined(separator: ", "))")
                    }
                    return
                }
                
                try await workOrdersDB.deleteWorkOrder(workOrder.id)
                await MainActor.run {
                    // Remove from local array
                    workOrders.removeAll { $0.id == workOrder.id }
                    print("🗑️ Deleted work order: \(workOrder.workOrderNumber)")
                }
            } catch {
                await MainActor.run {
                    setError("Failed to delete work order: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Toggle the flagged status of a work order
    func toggleFlagged(_ workOrder: WorkOrder) {
        Task {
            do {
                var updatedWorkOrder = workOrder
                updatedWorkOrder.flagged.toggle()
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = AppState.shared.currentUserName
                
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
                
                await MainActor.run {
                    // Update local array
                    if let index = workOrders.firstIndex(where: { $0.id == workOrder.id }) {
                        workOrders[index] = updatedWorkOrder
                    }
                    print("🚩 Toggled flag for work order: \(workOrder.workOrderNumber)")
                }
            } catch {
                await MainActor.run {
                    setError("Failed to toggle flag: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
