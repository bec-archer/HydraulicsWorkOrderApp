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

/*  ────────────────────────────────────────────────────────────────────────────
    WARNING — LOCKED VIEW (GUARDRAIL)
    GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT

    This view's layout, UI, and behavior are CRITICAL to the workflow and tests.
    DO NOT change, refactor, or alter layout/styling/functionality in this file.

    Allowed edits ONLY:
      • Comments and documentation
      • Preview sample data (non-shipping)
      • Bugfixes that are 100% no-visual-change (must be verifiable in Preview)

    Any change beyond the above requires explicit approval from Bec.
    Rationale: This screen matches shop SOPs and downstream QA expectations.
    ──────────────────────────────────────────────────────────────────────────── */

// MARK: - ViewModel Integration
// Using dedicated ActiveWorkOrdersViewModel from Views/ViewModels/

// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.
struct ActiveWorkOrdersView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = ActiveWorkOrdersViewModel()
    
    // MARK: - Dependencies
    @EnvironmentObject private var appState: AppState
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Body
    var body: some View {
        let _ = print("🔍 DEBUG: ActiveWorkOrdersView body being recreated")
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
                            ForEach(viewModel.activeWorkOrders, id: \.workOrderNumber) { workOrder in
                                WorkOrderCardView(workOrder: workOrder)
                                    .onTapGesture {
                                        print("🔍 DEBUG: WorkOrderCardView tapped for WO: \(workOrder.workOrderNumber)")
                                        // Navigate to work order detail using appState
                                        appState.navigateToWorkOrderDetail(workOrder)
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .refreshable {
            viewModel.refreshWorkOrders()
        }
        .navigationTitle("Active WorkOrders")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    print("🔍 DEBUG: Plus button tapped in ActiveWorkOrdersView")
                    print("🔍 DEBUG: Current appState.currentView: \(appState.currentView)")
                    print("🔍 DEBUG: Setting appState.currentView to .newWorkOrder")
                    appState.currentView = .newWorkOrder
                    print("🔍 DEBUG: New appState.currentView: \(appState.currentView)")
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Work Order")
            }
        }
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
        ActiveWorkOrdersView()
    }
    .environmentObject(AppState.shared)
}