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
    }
    // END INIT

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            // ───── Dev Login Toggle Logic ─────
            if DevSettingsManager.shared.skipLogin {
                RouterView()
                    .environmentObject(AppState.shared) // 👈 inject AppState
                    .environment(\.defaultMinListRowHeight, CGFloat(6)) // tighter rows everywhere
            } else {
                LoginView()
                    .environmentObject(AppState.shared) // also inject here for consistency
            }
        }
        // END .body
    }
}
