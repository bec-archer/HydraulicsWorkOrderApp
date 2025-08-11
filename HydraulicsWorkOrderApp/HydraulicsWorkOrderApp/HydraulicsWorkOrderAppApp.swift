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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            // ───── Dev Login Toggle Logic ─────
            if DevSettingsManager.shared.skipLogin {
                NewWorkOrderView() // 👈 swap this in for testing
// or SettingsView() if testing admin tools
            } else {
                LoginView()
            }
        }
        // END .body
    }
}
