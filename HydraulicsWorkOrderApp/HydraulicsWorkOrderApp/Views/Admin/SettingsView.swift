//
//  SettingsView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/12/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 SettingsView.swift
// Admin/Dev toggles for bypassing login, scan enforcement, sample reload
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct SettingsView: View {
    @ObservedObject var devSettings = DevSettingsManager.shared

    var body: some View {
        Form {
            // ───── Login Bypass ─────
            Section(header: Text("Developer Settings")) {
                Toggle("Bypass Login Screen", isOn: $devSettings.skipLogin)
                Toggle("Bypass Tag Scan Requirement", isOn: $devSettings.skipTagScan)
            }
        }
        .navigationTitle("Settings")
    }
}

// END .body

// END struct

// ───── Preview Template ─────
#Preview {
NavigationStack {
    SettingsView()
}
}
