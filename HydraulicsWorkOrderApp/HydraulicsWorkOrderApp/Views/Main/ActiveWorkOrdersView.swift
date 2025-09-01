//
//  ActiveWorkOrdersView_Refactored.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 ActiveWorkOrdersView_Refactored.swift
// Refactored version using ActiveWorkOrdersViewModel for better separation of concerns
// ─────────────────────────────────────────────────────────────

import SwiftUI
import Combine

// MARK: - ViewModel (Temporarily included for testing)
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
    // TODO: Re-enable after fixing module resolution
    // private let imageService = ImageManagementService.shared
    
    // MARK: - Computed Properties
    var activeWorkOrders: [WorkOrder] {
        // Remove duplicates by WO_Number, keeping the most recent one
        var uniqueWorkOrders: [String: WorkOrder] = [:]
        for workOrder in workOrders {
            if !workOrder.isDeleted && workOrder.status != "Closed" {
                // If we already have this WO_Number, keep the one with the most recent lastModified
                if let existing = uniqueWorkOrders[workOrder.WO_Number] {
                    // Prefer work orders with Firestore IDs, then most recent
                    let existingHasId = existing.id != nil && !existing.id!.isEmpty
                    let currentHasId = workOrder.id != nil && !workOrder.id!.isEmpty
                    
                    if currentHasId && !existingHasId {
                        // Current has ID, existing doesn't - prefer current
                        uniqueWorkOrders[workOrder.WO_Number] = workOrder
                    } else if !currentHasId && existingHasId {
                        // Existing has ID, current doesn't - keep existing
                        // Do nothing
                    } else if workOrder.lastModified > existing.lastModified {
                        // Both have same ID status, prefer most recent
                        uniqueWorkOrders[workOrder.WO_Number] = workOrder
                    }
                } else {
                    uniqueWorkOrders[workOrder.WO_Number] = workOrder
                }
            }
        }
        
        let active = Array(uniqueWorkOrders.values)
            .sorted {
                if $0.flagged != $1.flagged { return $0.flagged && !$1.flagged }
                return $0.timestamp < $1.timestamp
            }
        
        print("📋 ACTIVE: \(active.count) active work orders (total: \(workOrders.count))")
        
        return active
    }
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadWorkOrders()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor work orders database changes
        workOrdersDB.$workOrders
            .sink { [weak self] workOrders in
                self?.workOrders = workOrders
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load work orders from Firebase
    func loadWorkOrders() {
        isLoading = true
        errorMessage = nil
        
        workOrdersDB.fetchAllWorkOrders { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(_):
                    // Data is already loaded into the @ObservedObject workOrdersDB
                    
                    // Run migration for existing work orders to have WO Item IDs
                    self?.workOrdersDB.migrateExistingWorkOrdersToHaveWOItemIds { migrationResult in
                        DispatchQueue.main.async {
                            switch migrationResult {
                            case .success:
                                #if DEBUG
                                print("✅ WO Item ID migration completed successfully")
                                #endif
                            case .failure(let error):
                                #if DEBUG
                                print("⚠️ WO Item ID migration failed: \(error.localizedDescription)")
                                #endif
                                // Don't show error to user as this is a background migration
                            }
                        }
                    }
                    
                case .failure(let error):
                    self?.setError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Delete a work order
    func deleteWorkOrder(_ workOrder: WorkOrder) {
        // Only try to delete from Firestore if we have a document ID
        if let documentId = workOrder.id, !documentId.isEmpty {
            // Delete from Firestore first
            workOrdersDB.softDelete(workOrder) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ WorkOrder deleted successfully: \(workOrder.WO_Number)")
                        // Remove from local cache after successful Firestore delete
                        if let index = self?.workOrders.firstIndex(where: { $0.WO_Number == workOrder.WO_Number }) {
                            self?.workOrders.remove(at: index)
                        }
                    case .failure(let error):
                        print("❌ Failed to delete WorkOrder: \(error.localizedDescription)")
                        self?.setError("Failed to delete work order: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            print("⚠️ WorkOrder \(workOrder.WO_Number) has no document ID - attempting to find and delete from Firestore")
            // For legacy work orders without document IDs, try to find them in Firestore by WO_Number
            workOrdersDB.deleteLegacyWorkOrder(woNumber: workOrder.WO_Number) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Legacy WorkOrder \(workOrder.WO_Number) deleted from Firestore")
                        // Remove from local cache after successful Firestore delete
                        if let index = self?.workOrders.firstIndex(where: { $0.WO_Number == workOrder.WO_Number }) {
                            self?.workOrders.remove(at: index)
                        }
                    case .failure(let error):
                        print("❌ Failed to delete legacy WorkOrder from Firestore: \(error.localizedDescription)")
                        // Fall back to local cache marking
                        if let index = self?.workOrders.firstIndex(where: { $0.WO_Number == workOrder.WO_Number }) {
                            var updatedWorkOrder = self?.workOrders[index]
                            updatedWorkOrder?.isDeleted = true
                            if let updated = updatedWorkOrder {
                                self?.workOrders[index] = updated
                            }
                        }
                        self?.setError("Failed to delete legacy work order: \(error.localizedDescription)")
                    }
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

// MARK: - View
struct ActiveWorkOrdersView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = ActiveWorkOrdersViewModel()
    
    // MARK: - Dependencies
    @EnvironmentObject private var appState: AppState
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Loading State
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading Active WorkOrders…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.top, 32)
                }
                
                if !viewModel.isLoading {
                    // Empty State
                    if viewModel.activeWorkOrders.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No Active WorkOrders")
                                .font(.headline)
                            Text("Tap + New to check one in.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .padding(.top, 32)
                    } else {
                        // Work Order Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(viewModel.activeWorkOrders, id: \.WO_Number) { workOrder in
                                NavigationLink(destination: WorkOrderDetailView(
                                    workOrder: workOrder,
                                    onDelete: { deletedWorkOrder in
                                        viewModel.deleteWorkOrder(deletedWorkOrder)
                                    }
                                )) {
                                    WorkOrderCardView(workOrder: workOrder)
                                        .id(workOrder.WO_Number) // Add stable ID to prevent recreation
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadWorkOrders()
        }
        .onChange(of: appState.currentView) { _, newView in
            // Reset navigation path when app state changes (sidebar navigation)
            if newView != .activeWorkOrders {
                navigationPath = NavigationPath()
            }
            print("🔄 ActiveWorkOrdersView: appState.currentView changed to \(newView)")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .withOfflineStatus()
        .navigationTitle("Active Work Orders")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    appState.currentView = .newWorkOrder
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                }
                .accessibilityLabel("Add Work Order")
            }
            

        }
    }
}

// MARK: - Preview
#Preview {
    ActiveWorkOrdersView()
        .environmentObject(AppState.shared)
}
