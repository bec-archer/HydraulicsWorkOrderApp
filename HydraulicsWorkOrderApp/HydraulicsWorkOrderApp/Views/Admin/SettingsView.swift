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
            // ───── Developer Settings ─────
            Section(header: Text("Developer Settings")) {
                Toggle("Bypass Login Screen", isOn: $devSettings.skipLogin)
                Toggle("Bypass Tag Scan Requirement", isOn: $devSettings.skipTagScan)

                // 🔐 Enable anonymous Firebase Auth so image uploads work with strict rules
                Toggle("Enable Anonymous Firebase Auth", isOn: $devSettings.enableAnonAuth)
                    .accessibilityHint("Turn on to sign in anonymously at launch so Firebase Storage uploads are allowed")
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
