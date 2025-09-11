//
//  SimpleRouterView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
// ─────────────────────────────────────────────────────────────
// 📄 SimpleRouterView.swift
// Simple, reliable navigation without NavigationSplitView quirks
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct SimpleRouterView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSidebarVisible = false
    
    // MARK: - Computed Properties
    private var navigationTitle: String {
        switch appState.currentView {
        case .login:
            return "Login"
        case .activeWorkOrders:
            return "Active Work Orders"
        case .newWorkOrder:
            return "New Work Order"
        case .myWorkOrderItems:
            return "My Work Order Items"
        case .customers:
            return "Customers"
        case .myLoginInfo:
            return "My Login Info"
        case .settings:
            return "Settings"
        case .userManager:
            return "User Manager"
        case .dropdownManager:
            return "Dropdown Manager"
        case .workOrderDetail:
            return "Work Order Detail"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ───── Top Navigation Bar ─────
            HStack {
                // Sidebar toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.left")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#FFC500"))
                }
                .buttonStyle(.plain)
                
                Text(navigationTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // User info and logout
                HStack(spacing: 12) {
                    Text(appState.currentUserName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                            Button {
                                print("🔍 DEBUG: Logout button tapped")
                                // Reset user state
                                appState.currentUser = nil
                                appState.currentView = .login
                            } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                
                // Add New Work Order button
                Button {
                    print("🔍 DEBUG: Add New Work Order button tapped - navigating to new work order")
                    appState.currentView = .newWorkOrder
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Add New Work Order")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#FFC500"))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.systemGray6))
            
            // ───── Main Content Area ─────
            HStack(spacing: 0) {
                // ───── Sidebar ─────
                if isSidebarVisible {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Navigation")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            NavigationButton(
                                title: "Active Work Orders",
                                icon: "square.grid.2x2",
                                targetView: .activeWorkOrders,
                                currentView: appState.currentView,
                                onTap: { isSidebarVisible = false }
                            )
                            
                            NavigationButton(
                                title: "New Work Order",
                                icon: "plus.square.on.square",
                                targetView: .newWorkOrder,
                                currentView: appState.currentView,
                                onTap: { isSidebarVisible = false }
                            )
                            
                            NavigationButton(
                                title: "My Work Order Items",
                                icon: "doc.text.magnifyingglass",
                                targetView: .myWorkOrderItems,
                                currentView: appState.currentView,
                                onTap: { isSidebarVisible = false }
                            )
                            
                            NavigationButton(
                                title: "Customers",
                                icon: "person.2",
                                targetView: .customers,
                                currentView: appState.currentView,
                                onTap: { isSidebarVisible = false }
                            )
                            
                                    NavigationButton(
                                        title: "My Login Info",
                                        icon: "person.circle",
                                        targetView: .myLoginInfo,
                                        currentView: appState.currentView,
                                        onTap: { isSidebarVisible = false }
                                    )
                                    
                                    NavigationButton(
                                        title: "Settings",
                                        icon: "gearshape.fill",
                                        targetView: .settings,
                                        currentView: appState.currentView,
                                        onTap: { isSidebarVisible = false }
                                    )
                            
                            if appState.isAdmin || appState.isSuperAdmin {
                                NavigationButton(
                                    title: "Manage Users",
                                    icon: "person.2.circle",
                                    targetView: .userManager,
                                    currentView: appState.currentView,
                                    onTap: { isSidebarVisible = false }
                                )
                            }
                            
                            if appState.isAdmin || appState.isSuperAdmin || appState.isManager {
                                NavigationButton(
                                    title: "Dropdown Manager",
                                    icon: "chevron.down.square",
                                    targetView: .dropdownManager,
                                    currentView: appState.currentView,
                                    onTap: { isSidebarVisible = false }
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .frame(width: 200)
                    .background(Color(.systemGray6))
                    .transition(.move(edge: .leading))
                    
                    Divider()
                }
                
                // ───── Main Content ─────
                VStack {
                    switch appState.currentView {
                        case .login:
                            LoginView()
                        case .activeWorkOrders:
                            ActiveWorkOrdersView()
                        case .newWorkOrder:
                            NewWorkOrderView()
                        case .myWorkOrderItems:
                            MyWorkOrderItemsView()
                                .environmentObject(appState)
                        case .settings:
                            SettingsView()
                        case .userManager:
                            UserManagerView()
                                .environmentObject(appState)
                        case .dropdownManager:
                            DropdownManagerView()
                                .environmentObject(appState)
                        case .customers:
                            CustomersView()
                        case .myLoginInfo:
                            MyLoginInfoView()
                                .environmentObject(appState)
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
                                .onAppear { print("🔍 DEBUG: SimpleRouterView switching to WorkOrderDetailView for WO: \(workOrder.workOrderNumber)") }
                            } else {
                                Text("No work order selected")
                                    .onAppear { print("🔍 DEBUG: SimpleRouterView switching to WorkOrderDetailView but no work order selected") }
                            }
                        @unknown default:
                            Text("⚠️ Unknown AppScreen state")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // If dev bypass is enabled, ensure we have dev user credentials
            if DevSettingsManager.shared.skipLogin {
                if appState.currentUser == nil {
                    appState.currentUser = User(
                        id: "dev-user-id",
                        displayName: "Dev User",
                        phoneE164: nil,
                        role: .superadmin,
                        isActive: true,
                        pin: nil,
                        createdAt: Date(),
                        updatedAt: Date(),
                        createdByUserId: nil,
                        updatedByUserId: nil
                    )
                    appState.currentView = .activeWorkOrders
                }
            }
        }
    }
}

// ───── Reusable Navigation Button Component ─────
struct NavigationButton: View {
    let title: String
    let icon: String
    let targetView: AppScreen
    let currentView: AppScreen
    let onTap: (() -> Void)?
    
    var isSelected: Bool {
        currentView == targetView
    }
    
    var body: some View {
        Button {
            print("🔍 DEBUG: Navigation button '\(title)' tapped")
            print("🔍 DEBUG: Navigating from \(currentView) to \(targetView)")
            // Update AppState directly
            AppState.shared.currentView = targetView
            // Call the onTap callback if provided
            onTap?()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : .primary)
                Text(title)
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SimpleRouterView()
        .environmentObject(AppState.shared)
}
