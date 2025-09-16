//
//  ClosedWorkOrdersView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Assistant on 1/9/25.
//
//  View for displaying closed work orders - accessible by SuperAdmin, Admin, and Manager roles
//  Reuses ActiveWorkOrdersView with a filter for closed work orders only

import SwiftUI

struct ClosedWorkOrdersView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = ActiveWorkOrdersViewModel()
    
    // MARK: - Dependencies
    @EnvironmentObject private var appState: AppState
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Computed Properties
    private var closedWorkOrders: [WorkOrder] {
        // Use raw work orders from database, not the filtered activeWorkOrders
        let allWorkOrders = viewModel.workOrders
        let closed = allWorkOrders.filter { $0.isClosed && !$0.isDeleted }
        
        print("🔍 DEBUG: ClosedWorkOrdersView - Total work orders: \(allWorkOrders.count)")
        print("🔍 DEBUG: ClosedWorkOrdersView - Closed work orders: \(closed.count)")
        
        for workOrder in allWorkOrders {
            print("🔍 DEBUG: WO \(workOrder.workOrderNumber): Status=\(workOrder.status), isClosed=\(workOrder.isClosed), isDeleted=\(workOrder.isDeleted)")
            if workOrder.isClosed {
                print("  - Item statuses: \(workOrder.items.map { $0.statusHistory.last?.status ?? "none" })")
            }
        }
        
        return closed
    }
    
    private var flaggedClosedWorkOrders: [WorkOrder] {
        closedWorkOrders.filter { $0.flagged }
    }
    
    private var unflaggedClosedWorkOrders: [WorkOrder] {
        closedWorkOrders.filter { !$0.flagged }
    }
    
    // MARK: - Body
    var body: some View {
        let _ = print("🔍 DEBUG: ClosedWorkOrdersView body being recreated")
        ScrollView {
            VStack(spacing: 20) {
                // Loading State
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading Closed WorkOrders…")
                            .foregroundColor(ThemeManager.shared.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.top, 32)
                }
                
                if !viewModel.isLoading {
                    // Empty State
                    if closedWorkOrders.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "archivebox")
                                .font(.largeTitle)
                                .foregroundColor(ThemeManager.shared.textSecondary)
                            Text("No Closed WorkOrders")
                                .font(ThemeManager.shared.labelFont)
                                .foregroundColor(ThemeManager.shared.textPrimary)
                            Text("Closed work orders will appear here.")
                                .font(ThemeManager.shared.bodyFont)
                                .foregroundColor(ThemeManager.shared.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .padding(.top, 32)
                    } else {
                        // Work Order Grid with Flagged Sectioning
                        VStack(alignment: .leading, spacing: 20) {
                            // Flagged Section
                            if !flaggedClosedWorkOrders.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "flag.fill")
                                            .foregroundColor(ThemeManager.shared.linkColor)
                                            .font(.headline)
                                        
                                        Text("Flagged Closed")
                                            .font(ThemeManager.shared.labelFont)
                                            .foregroundColor(ThemeManager.shared.textPrimary)
                                        
                                        Spacer()
                                        
                                        Text("\(flaggedClosedWorkOrders.count)")
                                            .font(.caption)
                                            .foregroundColor(ThemeManager.shared.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(ThemeManager.shared.border.opacity(0.3))
                                            .cornerRadius(8)
                                    }
                                    .padding(.horizontal)
                                    
                                    LazyVGrid(columns: [
                                        GridItem(.flexible(), spacing: 16),
                                        GridItem(.flexible(), spacing: 16),
                                        GridItem(.flexible(), spacing: 16)
                                    ], spacing: 16) {
                                        ForEach(flaggedClosedWorkOrders, id: \.workOrderNumber) { workOrder in
                                            WorkOrderCardView(workOrder: workOrder)
                                                .onTapGesture {
                                                    print("🔍 DEBUG: Closed WorkOrderCardView tapped for WO: \(workOrder.workOrderNumber)")
                                                    appState.navigateToWorkOrderDetail(workOrder)
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // All Closed Section
                            if !unflaggedClosedWorkOrders.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "archivebox")
                                            .foregroundColor(ThemeManager.shared.textSecondary)
                                            .font(.headline)
                                        
                                        Text("All Closed")
                                            .font(ThemeManager.shared.labelFont)
                                            .foregroundColor(ThemeManager.shared.textPrimary)
                                        
                                        Spacer()
                                        
                                        Text("\(unflaggedClosedWorkOrders.count)")
                                            .font(.caption)
                                            .foregroundColor(ThemeManager.shared.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(ThemeManager.shared.border.opacity(0.3))
                                            .cornerRadius(8)
                                    }
                                    .padding(.horizontal)
                                    
                                    LazyVGrid(columns: [
                                        GridItem(.flexible(), spacing: 16),
                                        GridItem(.flexible(), spacing: 16),
                                        GridItem(.flexible(), spacing: 16)
                                    ], spacing: 16) {
                                        ForEach(unflaggedClosedWorkOrders, id: \.workOrderNumber) { workOrder in
                                            WorkOrderCardView(workOrder: workOrder)
                                                .onTapGesture {
                                                    print("🔍 DEBUG: Closed WorkOrderCardView tapped for WO: \(workOrder.workOrderNumber)")
                                                    appState.navigateToWorkOrderDetail(workOrder)
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            viewModel.refreshWorkOrders()
        }
        .navigationTitle("Closed WorkOrders")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            viewModel.loadWorkOrders()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ClosedWorkOrdersView()
    }
    .environmentObject(AppState.shared)
}
