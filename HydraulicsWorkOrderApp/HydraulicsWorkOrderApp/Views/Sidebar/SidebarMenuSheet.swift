//
//  SidebarMenuSheet.swift
//  HydraulicsWorkOrderApp
//
//  Created by <you> on <today>.
//

import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 SidebarMenuSheet.swift
// A lightweight sidebar presented as a sheet. Tech-friendly,
// big targets, yellow-accented. Uses AppState for routing.
// ─────────────────────────────────────────────────────────────

struct SidebarMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    // ───── Theme helpers (optional) ─────
    private let accentColor = Color("AppleNotesYellow")

    var body: some View {
        NavigationStack {
            List {
                // ───── Section: Navigation ─────
                Section("Navigation") {

                    // Active WorkOrders
                    Button {
                        appState.currentView = .activeWorkOrders
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.grid.2x2")
                                .font(.title2)
                            Text("Active WorkOrders")
                                .font(.title3.weight(.semibold))
                        }
                        .padding(.vertical, 4)
                    }

                    // Customers (placeholder – wire once CustomersView exists in Router)
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
                    Button {
                        appState.currentView = .settings
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape")
                                .font(.title2)
                            Text("Settings")
                                .font(.title3.weight(.semibold))
                        }
                        .padding(.vertical, 4)
                    }
                }
                // ───── END Section: Navigation ─────

                // ───── Section: Account ─────
                Section("Account") {
                    Button {
                        // Route to Settings for now; later: dedicated Change PIN screen
                        appState.currentView = .settings
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "key.horizontal")
                                .font(.title2)
                            Text("Change PIN")
                                .font(.title3.weight(.semibold))
                        }
                        .padding(.vertical, 4)
                    }
                }
                // ───── END Section: Account ─────
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Sidebar")
            .tint(Color("AppleNotesYellow"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.primary)
                }
            }

            // ───── END .toolbar ─────
        }
        // END .body
    }
}



// ───── Preview Template ─────
#Preview {
    SidebarMenuSheet()
        .environmentObject(AppState.shared)
}
