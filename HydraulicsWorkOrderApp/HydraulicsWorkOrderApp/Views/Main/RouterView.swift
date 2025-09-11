//
//  RouterView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/12/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 RouterView.swift
// Simple router to swap top-level views based on AppState
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct RouterView: View {
    @EnvironmentObject private var appState: AppState
    @State private var lastView: AppScreen = .activeWorkOrders

    var body: some View {
        // 🧭 Debug: Print current view state to console
        let _ = print("🧭 RouterView displaying: \(appState.currentView)")
        let _ = print("🔍 DEBUG: RouterView body being recreated")
        
        // Only recreate if view actually changed
        if appState.currentView != lastView {
            let _ = print("🔍 DEBUG: View changed from \(lastView) to \(appState.currentView)")
            let _ = lastView = appState.currentView
        }

        // ───── Split View Shell: Sidebar (left) + Detail (right) ─────
        NavigationSplitView(columnVisibility: $appState.splitVisibility) {

            // ───── Sidebar: Routes aligned to AppState ─────
            VStack {
                ScrollView {
                    VStack(spacing: 8) {

                // MAIN
                VStack(alignment: .leading, spacing: 8) {
                    Text("Main")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    HStack {
                        Image(systemName: "square.grid.2x2")
                        Text("Active WorkOrders")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🔍 DEBUG: Sidebar 'Active WorkOrders' button tapped")
                        appState.navigateToView(.activeWorkOrders)
                    }

                    HStack {
                        Image(systemName: "plus.square.on.square")
                        Text("New Work Order")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🔍 DEBUG: Sidebar 'New Work Order' button tapped")
                        print("🔍 DEBUG: Current appState.currentView: \(appState.currentView)")
                        print("🔍 DEBUG: Calling appState.navigateToView(.newWorkOrder)")
                        appState.navigateToView(.newWorkOrder)
                        print("🔍 DEBUG: After navigateToView, appState.currentView: \(appState.currentView)")
                    }

                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("My Work Order Items")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🔍 DEBUG: Sidebar 'My Work Order Items' button tapped")
                        appState.navigateToView(.myWorkOrderItems)
                    }

                    HStack {
                        Image(systemName: "person.2")
                        Text("Customers")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🔍 DEBUG: Sidebar 'Customers' button tapped")
                        appState.navigateToView(.customers)
                    }
                }
                
                // ADMIN / TOOLS
                VStack(alignment: .leading, spacing: 8) {
                    Text("Admin & Tools")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🔍 DEBUG: Sidebar 'Settings' button tapped")
                        appState.navigateToView(.settings)
                    }

                    // Users management (Admin/SuperAdmin only)
                    if appState.isAdmin || appState.isSuperAdmin {
                        HStack {
                            Image(systemName: "person.2.circle")
                            Text("Manage Users")
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("🔍 DEBUG: Sidebar 'Manage Users' button tapped")
                            appState.navigateToView(.userManager)
                        }
                    }

                    // Dropdown Manager (Admin/Manager access)
                    if appState.isAdmin || appState.isSuperAdmin || appState.isManager {
                        HStack {
                            Image(systemName: "chevron.down.square")
                            Text("Dropdown Manager")
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("🔍 DEBUG: Sidebar 'Dropdown Manager' button tapped")
                            appState.navigateToView(.dropdownManager)
                        }
                    }
                    Label("Deleted WorkOrders (coming soon)", systemImage: "trash")
                        .foregroundStyle(.secondary)
                }
                }
                }
            }
            // END Sidebar

        } detail: {
            // ───── Detail: Navigation handled by sidebar ─────
            ZStack {
                NavigationStack {
                    switch appState.currentView {
                        case .login:
                            LoginView()
                                .onAppear { print("🔍 DEBUG: RouterView switching to LoginView") }
                        case .activeWorkOrders:
                            ActiveWorkOrdersView()
                                .onAppear { print("🔍 DEBUG: RouterView switching to ActiveWorkOrdersView") }
                        case .newWorkOrder:
                            NewWorkOrderView()
                                .onAppear { print("🔍 DEBUG: RouterView switching to NewWorkOrderView") }
                        case .myWorkOrderItems:
                            MyWorkOrderItemsView()
                                .environmentObject(appState)
                                .onAppear { print("🔍 DEBUG: RouterView switching to MyWorkOrderItemsView") }
                        case .settings:
                            SettingsView()
                                .onAppear { print("🔍 DEBUG: RouterView switching to SettingsView") }
                        case .userManager:
                            UserManagerView()
                                .environmentObject(appState)
                                .onAppear { print("🔍 DEBUG: RouterView switching to UserManagerView") }
                        case .dropdownManager:
                            DropdownManagerView()
                                .environmentObject(appState)
                                .onAppear { print("🔍 DEBUG: RouterView switching to DropdownManagerView") }
                        case .customers:
                            CustomersView()
                                .onAppear { print("🔍 DEBUG: RouterView switching to CustomersView") }
                        case .myLoginInfo:
                            MyLoginInfoView()
                                .environmentObject(appState)
                                .onAppear { print("🔍 DEBUG: RouterView switching to MyLoginInfoView") }
                        case .workOrderDetail:
                            if let workOrder = appState.selectedWorkOrder {
                                WorkOrderDetailView(
                                    workOrder: workOrder,
                                    onDelete: { deletedWorkOrder in
                                        // Handle work order deletion
                                        print("🔍 DEBUG: Work order deleted: \(deletedWorkOrder.workOrderNumber)")
                                        appState.navigateToView(.activeWorkOrders)
                                    }
                                )
                                .onAppear { print("🔍 DEBUG: RouterView switching to WorkOrderDetailView for WO: \(workOrder.workOrderNumber)") }
                            } else {
                                Text("No work order selected")
                                    .onAppear { print("🔍 DEBUG: RouterView switching to WorkOrderDetailView but no work order selected") }
                            }
                        @unknown default:
                            Text("⚠️ Unknown AppScreen state")
                                .onAppear { print("🔍 DEBUG: RouterView switching to Unknown state") }
                    }
                }
                .id(appState.currentView) // Force recreation when app state changes
                .onAppear {
                    print("🔍 RouterView detail area showing: \(appState.currentView)")
                    print("🔍 RouterView selectedWorkOrder: \(appState.selectedWorkOrder?.workOrderNumber ?? "nil")")
                }
                .onChange(of: appState.currentView) { _, newView in
                    print("🔄 RouterView detail area switching to: \(newView)")
                }
                
                // Inactivity Warning Overlay
                VStack {
                    InactivityWarningView()
                        .environmentObject(appState)
                    Spacer()
                }
            }
        }
        .trackUserInteraction() // Track user interactions for inactivity monitoring
        // ───── END Split View Shell ─────
    }

}
// END struct

// ───── Preview Template ─────
#Preview {
    RouterView().environmentObject(AppState.shared)
}
