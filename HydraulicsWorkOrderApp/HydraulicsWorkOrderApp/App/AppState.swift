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
    case newWorkOrder
    case customers
    case settings
    case userManager
    // Add more cases as needed (e.g., completedWorkOrders, etc.)
}
// END enum


// ───── CLASS: AppState (ObservableObject) ─────
@MainActor
class AppState: ObservableObject {
    static let shared = AppState() // Singleton for global access
    
    @Published var currentView: AppScreen = .activeWorkOrders

    // ───── Current Logged-in User Info ─────
    @Published var currentUserName: String = "Admin User"  // Default name for testing
    @Published var currentUserRole: UserRole = .admin      // Default to admin for testing (bypasses login)
    
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
        s.currentUserRole = role
        s.currentUserName = "Preview \(role.rawValue.capitalized)"
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
        currentView = view
        splitVisibility = .detailOnly
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


    private init() {}  // Singleton enforcement
    

}
// END class

// ───── PREVIEW (No UI) ─────
#Preview {
    Text("AppState.swift")
}
