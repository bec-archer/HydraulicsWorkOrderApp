//
//  SettingsView 2.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//


// ───── SETTINGS VIEW ─────
import SwiftUI

/// Admin/SuperAdmin-only settings panel.
/// Provides access to sync health, dropdowns, user manager,
/// and SuperAdmin dev toggles (login enforcement, scan enforcement, sample reset).
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // ───── BODY ─────
        NavigationStack {
            List {
                // Admin + SuperAdmin tools
                if appState.isAdmin || appState.isSuperAdmin {
                    NavigationLink("Manage Users", destination: UserManagerView()
                        .environmentObject(appState))

                    NavigationLink("Sync Status", destination: SyncStatusView()
                        .environmentObject(appState))
                }

                // SuperAdmin-only dev toggles
                if appState.isSuperAdmin {
                    Section("Developer Toggles") {
                        Toggle("Disable Login Screen", isOn: Binding(
                            get: { DevSettingsManager.shared.skipLogin },
                            set: { DevSettingsManager.shared.skipLogin = $0 }
                        ))
                        Toggle("Bypass Tag Scan Enforcement", isOn: Binding(
                            get: { DevSettingsManager.shared.skipTagScan },
                            set: { DevSettingsManager.shared.skipTagScan = $0 }
                        ))
                        Button("Reload Sample Data") {
                            // TODO: wire sample data loader
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        // END
    }
}

// ───── PREVIEW ─────
#Preview {
    let s = AppState.previewLoggedIn(role: .superadmin)
    SettingsView()
        .environmentObject(s)
}
// END
