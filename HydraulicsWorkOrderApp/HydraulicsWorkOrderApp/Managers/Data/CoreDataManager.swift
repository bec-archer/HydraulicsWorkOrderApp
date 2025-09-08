//
//  CoreDataManager.swift
//  HydraulicsWorkOrderApp
//
//  Core Data manager for offline-first database operations
//
import Foundation
import CoreData
import Combine

@MainActor
final class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    // MARK: - Published Properties
    @Published var workOrders: [WorkOrder] = []
    @Published var customers: [Customer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let container: NSPersistentContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        container = NSPersistentContainer(name: "OfflineWorkOrders")
        setupContainer()
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupContainer() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("❌ Core Data: Failed to load persistent store: \(error.localizedDescription)")
                self.errorMessage = "Failed to load database: \(error.localizedDescription)"
            } else {
                print("✅ Core Data: Successfully loaded persistent store")
            }
        }
        
        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    private func setupBindings() {
        // Monitor for changes and update published properties
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Context Management
    private var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    private func saveContext() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                print("✅ Core Data: Context saved successfully")
            } catch {
                print("❌ Core Data: Failed to save context: \(error.localizedDescription)")
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Data Refresh
    private func refreshData() {
        Task {
            await loadWorkOrders()
            await loadCustomers()
        }
    }
    
    // MARK: - Work Order Operations
    
    func loadWorkOrders() async {
        isLoading = true
        
        // TODO: Implement when Core Data classes are generated
        print("⚠️ Core Data classes not yet generated - skipping loadWorkOrders")
        
        await MainActor.run {
            self.workOrders = []
            self.isLoading = false
        }
    }
    
    func saveWorkOrder(_ workOrder: WorkOrder) async throws {
        // TODO: Implement when Core Data classes are generated
        print("⚠️ Core Data classes not yet generated - skipping saveWorkOrder")
        
        // For now, just add to the local array
        await MainActor.run {
            if let index = self.workOrders.firstIndex(where: { $0.id == workOrder.id }) {
                self.workOrders[index] = workOrder
            } else {
                self.workOrders.append(workOrder)
            }
        }
    }
    
    func deleteWorkOrder(_ workOrder: WorkOrder) async throws {
        // TODO: Implement when Core Data classes are generated
        print("⚠️ Core Data classes not yet generated - skipping deleteWorkOrder")
        
        await MainActor.run {
            self.workOrders.removeAll { $0.id == workOrder.id }
        }
    }
    
    // MARK: - Customer Operations
    
    func loadCustomers() async {
        // TODO: Implement when Core Data classes are generated
        print("⚠️ Core Data classes not yet generated - skipping loadCustomers")
        
        await MainActor.run {
            self.customers = []
        }
    }
    
    func saveCustomer(_ customer: Customer) async throws {
        // TODO: Implement when Core Data classes are generated
        print("⚠️ Core Data classes not yet generated - skipping saveCustomer")
        
        await MainActor.run {
            if let index = self.customers.firstIndex(where: { $0.id == customer.id }) {
                self.customers[index] = customer
            } else {
                self.customers.append(customer)
            }
        }
    }
    
    func deleteCustomer(_ customer: Customer) async throws {
        // TODO: Implement when Core Data classes are generated
        print("⚠️ Core Data classes not yet generated - skipping deleteCustomer")
        
        await MainActor.run {
            self.customers.removeAll { $0.id == customer.id }
        }
    }
}

// MARK: - Extensions
extension CoreDataManager {
    
    // MARK: - Search and Filter
    func searchWorkOrders(query: String) async -> [WorkOrder] {
        // TODO: Implement when Core Data classes are generated
        return workOrders.filter { workOrder in
            workOrder.workOrderNumber.localizedCaseInsensitiveContains(query) ||
            workOrder.customerName.localizedCaseInsensitiveContains(query) ||
            workOrder.workOrderType.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getWorkOrdersByStatus(_ status: String) async -> [WorkOrder] {
        // TODO: Implement when Core Data classes are generated
        return workOrders.filter { $0.status == status }
    }
    
    // MARK: - Statistics
    func getWorkOrderStats() async -> (total: Int, checkedIn: Int, inProgress: Int, completed: Int) {
        let total = workOrders.count
        let checkedIn = workOrders.filter { $0.status == "Checked In" }.count
        let inProgress = workOrders.filter { $0.status == "In Progress" }.count
        let completed = workOrders.filter { $0.status == "Done" || $0.status == "Completed" }.count
        
        return (total, checkedIn, inProgress, completed)
    }
}
