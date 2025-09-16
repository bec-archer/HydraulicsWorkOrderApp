//
//  AppState.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/12/25.
//

import Foundation
import SwiftUI

// ───── ENUM: App Screens ─────
enum AppScreen {
    case login
    case activeWorkOrders
    case closedWorkOrders  // NEW: Closed work orders view for Admin/Manager/SuperAdmin
    case newWorkOrder
    case myWorkOrderItems
    case customers
    case myLoginInfo
    case settings
    case userManager
    case dropdownManager
    case workOrderDetail
    case workOrderItemDetail  // NEW: Individual work order item detail view
    case qrBatchGenerator   // NEW: Admin/Manager-only QR sheet generator
    // Add more cases as needed (e.g., completedWorkOrders, etc.)
}
// END enum


// ───── CLASS: AppState (ObservableObject) ─────
@MainActor
class AppState: ObservableObject {
    static let shared = AppState() // Singleton for global access
    
    @Published var currentView: AppScreen = .activeWorkOrders
    @Published var selectedWorkOrder: WorkOrder? = nil  // For work order detail navigation
    @Published var selectedWorkOrderItem: WO_Item? = nil  // For work order item detail navigation
    @Published var selectedWorkOrderItemIndex: Int? = nil  // Index of the item in the work order
    
    // Action triggers for cross-view communication
    @Published var triggerCheckInWorkOrder: Bool = false  // Trigger check-in from SimpleRouterView

    // ───── Current Logged-in User Info ─────
    @Published var currentUser: User? = nil  // The actual logged-in user from database
    
    // Computed properties for backward compatibility
    var currentUserName: String { 
        currentUser?.displayName ?? "Guest"
    }
    var currentUserRole: UserRole { 
        currentUser?.role ?? .tech
    }
    
    // ───── Current User Helpers (Role Gates) ─────
    /// Convenience gates used throughout Admin/Users views.
    var isTech: Bool       { currentUserRole == .tech }
    var isManager: Bool    { currentUserRole == .manager }
    var isAdmin: Bool      { currentUserRole == .admin }
    var isSuperAdmin: Bool { currentUserRole == .superadmin }
    
    /// Preview helper for Xcode Previews—avoids wiring real auth:
    /// Example: `let appState = AppState.previewLoggedIn(role: .admin)`
    static func previewLoggedIn(role: UserRole) -> AppState {
        let s = AppState()
        s.currentUser = User(
            id: "preview-user-id",
            displayName: "Preview \(role.rawValue.capitalized)",
            phoneE164: nil,
            role: role,
            isActive: true,
            pin: nil,
            createdAt: Date(),
            updatedAt: Date(),
            createdByUserId: nil,
            updatedByUserId: nil
        )
        return s
    }
    // END role helpers
    // ───── Sidebar Visibility (Split View) ─────
    // Controls whether the left sidebar is shown on iPad
    @Published var splitVisibility: NavigationSplitViewVisibility = .detailOnly

    // Simple toggle used by hamburger button
    func toggleSidebar() {
        // Use if/else so we never hit “Switch must be exhaustive”
        if splitVisibility == .all {
            splitVisibility = .detailOnly     // hide
        } else {
            splitVisibility = .all            // show
        }
    }
    
    // Navigate to a view and automatically collapse sidebar
    func navigateToView(_ view: AppScreen) {
        print("🔍 DEBUG: AppState.navigateToView called with: \(view)")
        print("🔍 DEBUG: Previous currentView: \(currentView)")
        currentView = view
        print("🔍 DEBUG: New currentView: \(currentView)")
        splitVisibility = .detailOnly
        print("🔍 DEBUG: Sidebar collapsed to detailOnly")
    }
    
    // Navigate to work order detail
    func navigateToWorkOrderDetail(_ workOrder: WorkOrder) {
        print("🔍 DEBUG: AppState.navigateToWorkOrderDetail called with WO: \(workOrder.workOrderNumber)")
        print("🔍 DEBUG: Setting selectedWorkOrder to: \(workOrder.workOrderNumber)")
        selectedWorkOrder = workOrder
        print("🔍 DEBUG: Setting currentView to: .workOrderDetail")
        currentView = .workOrderDetail
        print("🔍 DEBUG: Current currentView is now: \(currentView)")
        splitVisibility = .detailOnly
    }
    
    // Trigger check-in from SimpleRouterView
    func triggerCheckIn() {
        print("🔍 DEBUG: AppState.triggerCheckIn called")
        triggerCheckInWorkOrder.toggle()  // Toggle to trigger the action
    }
    
    // Navigate to work order item detail
    func navigateToWorkOrderItemDetail(_ workOrder: WorkOrder, item: WO_Item, itemIndex: Int) {
        print("🔍 DEBUG: AppState.navigateToWorkOrderItemDetail called with WO: \(workOrder.workOrderNumber), Item: \(item.type)")
        print("🔍 DEBUG: Setting selectedWorkOrder to: \(workOrder.workOrderNumber)")
        selectedWorkOrder = workOrder
        print("🔍 DEBUG: Setting selectedWorkOrderItem to: \(item.type)")
        selectedWorkOrderItem = item
        print("🔍 DEBUG: Setting selectedWorkOrderItemIndex to: \(itemIndex)")
        selectedWorkOrderItemIndex = itemIndex
        print("🔍 DEBUG: Setting currentView to: .workOrderItemDetail")
        currentView = .workOrderItemDetail
        print("🔍 DEBUG: Current currentView is now: \(currentView)")
        splitVisibility = .detailOnly
        print("🔍 DEBUG: Navigation complete")
    }


    func canDeleteWorkOrders() -> Bool {
        return currentUserRole == .manager ||
               currentUserRole == .admin ||
               currentUserRole == .superadmin
    }



    // ───── SuperAdmin Security (dev toggles) ─────
    // Set this to YOUR SuperAdmin PIN for now. Later we’ll wire it to your real user store.
    @Published var superAdminName: String = "Bec Archer"
    @Published var superAdminPIN: String = "56743"   // Master PIN, correct as provided

    // Centralized check used by dev-only controls (e.g., bypass login)
    func verifySuperAdmin(pin: String) -> Bool {
        // Don’t require role here while login is bypassed; just match the PIN.
        // When login is enforced, you can tighten with: `&& currentUserRole == .superadmin`
        return pin == superAdminPIN
    }


    private init() {
        setupInactivityMonitoring()
    }
    
    // MARK: - Setup
    private func setupInactivityMonitoring() {
        // Listen for inactivity logout notifications
        NotificationCenter.default.addObserver(
            forName: .inactivityLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleInactivityLogout()
            }
        }
    }
    
    private func handleInactivityLogout() {
        print("🔍 DEBUG: handleInactivityLogout called")
        print("🔍 DEBUG: DevSettingsManager.shared.skipLogin = \(DevSettingsManager.shared.skipLogin)")
        
        // Skip logout if dev bypass is enabled
        if DevSettingsManager.shared.skipLogin {
            print("🔍 DEBUG: Inactivity logout skipped - dev bypass enabled")
            return
        }
        
        print("🔍 DEBUG: Performing inactivity logout")
        // Reset to login screen
        currentView = .login
        currentUser = nil // Clear the logged-in user
    }
    

}
// END class

// ───── PREVIEW (No UI) ─────
#Preview {
    Text("AppState.swift")
}
