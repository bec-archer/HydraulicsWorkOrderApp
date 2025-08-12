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

    private init() {}  // Singleton enforcement
}
// END class

// ───── PREVIEW (No UI) ─────
#Preview {
    Text("AppState.swift")
}
