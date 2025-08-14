//
//  SidebarMenuContent.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 SidebarMenuContent.swift
// Shared sidebar menu layout used by both:
//   • SidebarMenuView (persistent NavigationSplitView sidebar)
//   • SidebarMenuSheet (dismissable sheet menu)
// Keeps all menu items in one place for easier updates.
// ─────────────────────────────────────────────────────────────

struct SidebarMenuContent: View {
    @EnvironmentObject private var appState: AppState

    // Optional action for sheet version to close itself after selection
    var dismissAction: (() -> Void)? = nil

    var body: some View {
        List {
            // ───── Section: Navigation ─────
            Section("Navigation") {

                // Active WorkOrders
                Button {
                    appState.currentView = .activeWorkOrders
                    dismissAction?()
                } label: {
                    Label("Active WorkOrders", systemImage: "rectangle.grid.2x2")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 4)
                }

                // Customers placeholder (future CustomersView wiring)
                HStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Customers")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Coming soon")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                // Settings
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 4)
                }
            }
            // ───── END Section: Navigation ─────

            // ───── Section: Account ─────
            Section("Account") {
                Button {
                    appState.currentView = .settings
                    dismissAction?()
                } label: {
                    Label("Change PIN", systemImage: "key.horizontal")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 4)
                }
            }
            // ───── END Section: Account ─────
        }
        .tint(Color("AppleNotesYellow"))
    }
}

// ───── Preview Template ─────
#Preview {
    SidebarMenuContent()
        .environmentObject(AppState.shared)
}
