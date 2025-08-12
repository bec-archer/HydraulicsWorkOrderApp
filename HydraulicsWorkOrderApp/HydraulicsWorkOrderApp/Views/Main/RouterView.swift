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
    @EnvironmentObject var appState: AppState

    var body: some View {
        // 🧭 Debug: Print current view state to console
        let _ = print("🧭 RouterView displaying: \(appState.currentView)")

        return Group {
            switch appState.currentView {
            case .login:
                LoginView()

            case .activeWorkOrders:
                ActiveWorkOrdersView()

            case .newWorkOrder:
                NewWorkOrderView()

            case .settings:
                SettingsView()

            @unknown default:
                Text("⚠️ Unknown AppScreen state")
            }
        }
    }
}
// END struct

// ───── Preview Template ─────
#Preview {
    RouterView().environmentObject(AppState.shared)
}
