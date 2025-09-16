//
//  HydraulicsWorkOrderAppApp.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
// ─────────────────────────────────────────────────────────────
// 📄 HydraulicsWorkOrderAppApp.swift
// App entry point w/ DevSettings login bypass support
// ─────────────────────────────────────────────────────────────

import SwiftUI

@main
struct HydraulicsWorkOrderAppApp: App {
    init() {
        // ───── Global Form/List spacing tune ─────
        UITableView.appearance().sectionHeaderTopPadding = 6      // iOS 15+
        UITableView.appearance().sectionFooterHeight = 6           // tighten footers
        UITableView.appearance().estimatedSectionFooterHeight = 6  // keep estimates in sync
        // END Global spacing tune
        
        // Start inactivity monitoring
        Task { @MainActor in
            InactivityManager.shared.startMonitoring()
        }
    }
    // END INIT

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            // ───── Authentication-First Logic ─────
            if DevSettingsManager.shared.skipLogin {
                // Dev bypass: Create dev user immediately and show main app
                DevBypassView()
                    .environmentObject(AppState.shared)
                    .environment(\.defaultMinListRowHeight, 6.0)
            } else {
                // Production: Show login screen
                LoginView()
                    .environmentObject(AppState.shared)
                    .environment(\.defaultMinListRowHeight, 6.0)
            }
        }
        // END .body
    }
}
