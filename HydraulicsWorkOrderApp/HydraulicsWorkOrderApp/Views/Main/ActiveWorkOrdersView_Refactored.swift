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
    
    // MARK: - Computed Properties
    var activeWorkOrders: [WorkOrder] {
        // Remove duplicates by WO_Number, keeping the most recent one
        var uniqueWorkOrders: [String: WorkOrder] = [:]
        for workOrder in workOrders {
            if !workOrder.isDeleted && !workOrder.isClosed {
                // If we already have this WO_Number, keep the one with the most recent lastModified
                if let existing = uniqueWorkOrders[workOrder.workOrderNumber] {
                    // Prefer work orders with Firestore IDs, then most recent
                    let existingHasId = existing.id != nil && !existing.id!.isEmpty
                    let currentHasId = workOrder.id != nil && !workOrder.id!.isEmpty
                    
                    if currentHasId && !existingHasId {
                        // Current has ID, existing doesn't - prefer current
                        uniqueWorkOrders[workOrder.workOrderNumber] = workOrder
                    } else if !currentHasId && existingHasId {
                        // Existing has ID, current doesn't - keep existing
                        // Do nothing
                    } else if workOrder.lastModified > existing.lastModified {
                        // Both have same ID status, prefer most recent
                        uniqueWorkOrders[workOrder.workOrderNumber] = workOrder
                    }
                } else {
                    uniqueWorkOrders[workOrder.workOrderNumber] = workOrder
                }
            }
        }
        
        let active = Array(uniqueWorkOrders.values)
            .sorted {
                if $0.flagged != $1.flagged { return $0.flagged && !$1.flagged }
                return $0.timestamp < $1.timestamp
            }
        
        #if DEBUG
        print("📋 ActiveWorkOrdersView: Found \(active.count) active work orders out of \(workOrders.count) total")
        #endif
        
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
                    break
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
                        print("✅ WorkOrder deleted successfully: \(workOrder.workOrderNumber)")
                        // Remove from local cache after successful Firestore delete
                        if let index = self?.workOrders.firstIndex(where: { $0.workOrderNumber == workOrder.workOrderNumber }) {
                            self?.workOrders.remove(at: index)
                        }
                    case .failure(let error):
                        print("❌ Failed to delete WorkOrder: \(error.localizedDescription)")
                        self?.setError("Failed to delete work order: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            print("⚠️ WorkOrder \(workOrder.workOrderNumber) has no document ID - attempting to find and delete from Firestore")
            // For legacy work orders without document IDs, try to find them in Firestore by WO_Number
            workOrdersDB.deleteLegacyWorkOrder(woNumber: workOrder.workOrderNumber) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Legacy WorkOrder \(workOrder.workOrderNumber) deleted from Firestore")
                        // Remove from local cache after successful Firestore delete
                        if let index = self?.workOrders.firstIndex(where: { $0.workOrderNumber == workOrder.workOrderNumber }) {
                            self?.workOrders.remove(at: index)
                        }
                    case .failure(let error):
                        print("❌ Failed to delete legacy WorkOrder from Firestore: \(error.localizedDescription)")
                        // Fall back to local cache marking
                        if let index = self?.workOrders.firstIndex(where: { $0.workOrderNumber == workOrder.workOrderNumber }) {
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
struct ActiveWorkOrdersView_Refactored: View {
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
                        // Work Order Grid - Calculate dimensions based on screen size and orientation
                        GeometryReader { geometry in
                            let screenWidth = geometry.size.width
                            let horizontalPadding: CGFloat = 16
                            let cardSpacing: CGFloat = 16
                            
                            // Simple approach: determine cards based on screen width thresholds
                            let cardsPerRow: Int
                            if screenWidth > 1000 {
                                cardsPerRow = 4  // Landscape mode - 4 cards
                            } else {
                                cardsPerRow = 3  // Portrait mode - 3 cards
                            }
                            
                            let availableWidth = screenWidth - (horizontalPadding * 2)
                            let finalCardWidth = (availableWidth - (cardSpacing * CGFloat(cardsPerRow - 1))) / CGFloat(cardsPerRow)
                            
                            // Debug: Print the calculation results
                            print("🖥️ Screen width: \(screenWidth)")
                            print("📐 Available width: \(availableWidth)")
                            print("📊 Cards per row: \(cardsPerRow)")
                            print("📏 Final card width: \(finalCardWidth)")
                            
                            // Calculate image area size - scale with card width for better space utilization
                            let imageAreaWidth = finalCardWidth - 32 // Account for text content padding (16 on each side)
                            let imageAreaHeight = min(imageAreaWidth, 200) // Cap height at 200pt to prevent cards from being too tall
                            let imageAreaSize = min(imageAreaWidth, imageAreaHeight) // Use the smaller dimension for square images
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(finalCardWidth), spacing: cardSpacing), count: cardsPerRow), spacing: cardSpacing) {
                                ForEach(viewModel.activeWorkOrders, id: \.workOrderNumber) { workOrder in
                                    NavigationLink(destination: WorkOrderDetailView(
                                        workOrder: workOrder,
                                        onDelete: { deletedWorkOrder in
                                            viewModel.deleteWorkOrder(deletedWorkOrder)
                                        }
                                    )) {
                                        WorkOrderCardView(workOrder: workOrder, imageAreaSize: imageAreaSize)
                                            .id(workOrder.workOrderNumber) // Add stable ID to prevent recreation
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                        }
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
    ActiveWorkOrdersView_Refactored()
        .environmentObject(AppState.shared)
}
