//
//  HydraulicsWorkOrderAppApp.swift
//  HydraulicsWorkOrderApp
//
//  Recreated to fix duplicate AppDelegate + blank screen.
//

import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 HydraulicsWorkOrderAppApp.swift
// App entry point — relies on AppDelegate.swift for Firebase
// ─────────────────────────────────────────────────────────────

@main
struct HydraulicsWorkOrderAppApp: App {

    // Use the existing AppDelegate (defined in App/AppDelegate.swift)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // ───── BODY ─────
    var body: some Scene {
        WindowGroup {
            // Keep routing simple until launch is stable
            ActiveWorkOrdersView()
        }
        // END .body
    }
}
// END App
