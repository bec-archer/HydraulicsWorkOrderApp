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
    case settings
    // Add more cases as needed (e.g., completedWorkOrders, userManager, etc.)
}
// END enum


// ───── CLASS: AppState (ObservableObject) ─────
@MainActor
class AppState: ObservableObject {
    static let shared = AppState() // Singleton for global access
    
    @Published var currentView: AppScreen = .newWorkOrder

    // ───── Current Logged-in User Info ─────
    @Published var currentUserName: String = ""
    @Published var currentUserRole: UserRole = .tech

    // ───── SuperAdmin Security (dev toggles) ─────
    // Set this to YOUR SuperAdmin PIN for now. Later we’ll wire it to your real user store.
    @Published var superAdminPIN: String = "56743"

    // Centralized check used by dev-only controls (e.g., bypass login)
    func verifySuperAdmin(pin: String) -> Bool {
        // Don’t require role here while login is bypassed; just match the PIN.
        // When login is enforced, you can tighten with: `&& currentUserRole == .superadmin`
        return pin == superAdminPIN
    }


    private init() {}  // Singleton enforcement
    
    // ───── Helper: Role Check ─────
    func canDeleteWorkOrders() -> Bool {
        switch currentUserRole {
        case .manager, .admin, .superadmin:
            return true
        default:
            return false
        }
    }
}
// END class

// ───── PREVIEW (No UI) ─────
#Preview {
    Text("AppState.swift")
}
