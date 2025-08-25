//
//  ActiveWorkOrdersView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//

import SwiftUI

struct ActiveWorkOrdersView: View {
    @ObservedObject var db = WorkOrdersDatabase.shared
    @EnvironmentObject private var appState: AppState
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigationPath = NavigationPath()

    // Computed property for active work orders
    private var activeWorkOrders: [WorkOrder] {
        let active = db.workOrders
            .filter { !$0.isDeleted && $0.status != "Closed" }
            .sorted {
                if $0.flagged != $1.flagged { return $0.flagged && !$1.flagged }
                return $0.timestamp < $1.timestamp
            }
        
        #if DEBUG
        print("📋 ActiveWorkOrdersView: Found \(active.count) active work orders out of \(db.workOrders.count) total")
        #endif
        
        return active
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ───── Loading State ─────
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading Active WorkOrders…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.top, 32)
                }
                
                if !isLoading {
                    // ───── Empty State ─────
                    if activeWorkOrders.isEmpty {
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
                        // ───── Work Order Grid ─────
                        GeometryReader { geometry in
                            let spacing: CGFloat = 16
                            let availableWidth = geometry.size.width - 32 // Account for horizontal padding
                            let cardWidth = (availableWidth - spacing * 2) / 3 // 3 cards with 2 spaces between
                            
                            LazyVGrid(columns: [
                                GridItem(.fixed(cardWidth), spacing: spacing),
                                GridItem(.fixed(cardWidth), spacing: spacing),
                                GridItem(.fixed(cardWidth), spacing: spacing)
                            ], spacing: spacing) {
                                ForEach(activeWorkOrders, id: \.WO_Number) { workOrder in
                                    NavigationLink(destination: WorkOrderDetailView(
                                        workOrder: workOrder,
                                        onDelete: { deletedWorkOrder in
                                            // Only try to delete from Firestore if we have a document ID
                                            if let documentId = deletedWorkOrder.id, !documentId.isEmpty {
                                                // Delete from Firestore first
                                                WorkOrdersDatabase.shared.softDelete(deletedWorkOrder) { result in
                                                    DispatchQueue.main.async {
                                                        switch result {
                                                        case .success:
                                                            print("✅ WorkOrder deleted successfully: \(deletedWorkOrder.WO_Number)")
                                                            // Remove from local cache after successful Firestore delete
                                                            if let index = db.workOrders.firstIndex(where: { $0.WO_Number == deletedWorkOrder.WO_Number }) {
                                                                db.workOrders.remove(at: index)
                                                            }
                                                        case .failure(let error):
                                                            print("❌ Failed to delete WorkOrder: \(error.localizedDescription)")
                                                            // Optionally show error to user
                                                        }
                                                    }
                                                }
                                            } else {
                                                print("⚠️ WorkOrder \(deletedWorkOrder.WO_Number) has no document ID - attempting to find and delete from Firestore")
                                                // For legacy work orders without document IDs, try to find them in Firestore by WO_Number
                                                WorkOrdersDatabase.shared.deleteLegacyWorkOrder(woNumber: deletedWorkOrder.WO_Number) { result in
                                                    DispatchQueue.main.async {
                                                        switch result {
                                                        case .success:
                                                            print("✅ Legacy WorkOrder \(deletedWorkOrder.WO_Number) deleted from Firestore")
                                                            // Remove from local cache after successful Firestore delete
                                                            if let index = db.workOrders.firstIndex(where: { $0.WO_Number == deletedWorkOrder.WO_Number }) {
                                                                db.workOrders.remove(at: index)
                                                            }
                                                        case .failure(let error):
                                                            print("❌ Failed to delete legacy WorkOrder from Firestore: \(error.localizedDescription)")
                                                            // Fall back to local cache marking
                                                            if let index = db.workOrders.firstIndex(where: { $0.WO_Number == deletedWorkOrder.WO_Number }) {
                                                                var updatedWorkOrder = db.workOrders[index]
                                                                updatedWorkOrder.isDeleted = true
                                                                db.workOrders[index] = updatedWorkOrder
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    )) {
                                        WorkOrderCardView(workOrder: workOrder)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
        .refreshable {
            loadWorkOrders()
        }
        .onAppear {
            // Only load from Firestore if local cache is empty
            if db.workOrders.isEmpty {
                loadWorkOrders()
            } else {
                isLoading = false
            }
        }
        .onChange(of: appState.currentView) { _, newView in
            // Reset navigation path when app state changes (sidebar navigation)
            if newView != .activeWorkOrders {
                navigationPath = NavigationPath()
            }
            print("🔄 ActiveWorkOrdersView: appState.currentView changed to \(newView)")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
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

    // ───── Load Work Orders ─────
    private func loadWorkOrders() {
        isLoading = true
        
        WorkOrdersDatabase.shared.fetchAllWorkOrders { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(_):
                    // Data is already loaded into the @ObservedObject db
                    break
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    ActiveWorkOrdersView()
        .environmentObject(AppState.shared)
}