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
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        // 🧭 Debug: Print current view state to console
        let _ = print("🧭 RouterView displaying: \(appState.currentView)")

        // ───── Split View Shell: Sidebar (left) + Detail (right) ─────
        NavigationSplitView(columnVisibility: $appState.splitVisibility) {

            // ───── Sidebar: Routes aligned to AppState ─────
            List {

                // MAIN
                Section("Main") {
                    Button {
                        appState.currentView = .activeWorkOrders
                    } label: {
                        Label("Active WorkOrders", systemImage: "square.grid.2x2")
                    }

                    Button {
                        appState.currentView = .newWorkOrder
                    } label: {
                        Label("New Work Order", systemImage: "plus.square.on.square")
                    }

                    Button {
                        appState.currentView = .customers
                    } label: {
                        Label("Customers", systemImage: "person.2")
                    }
                }

                // ADMIN / TOOLS
                Section("Admin & Tools") {
                    Button {
                        appState.currentView = .settings
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }

                    // Placeholders (keep visible for roadmap; disabled = no compile impact)

                    Label("Dropdown Manager (coming soon)", systemImage: "chevron.down.square")
                        .foregroundStyle(.secondary)
                    Label("Deleted WorkOrders (coming soon)", systemImage: "trash")
                        .foregroundStyle(.secondary)
                }
            }
            // END Sidebar

        } detail: {
            // ───── Detail: Navigation handled by sidebar ─────
            NavigationStack {
                Group {
                    switch appState.currentView {
                    case .login:
                        LoginView()
                    case .activeWorkOrders:
                        ActiveWorkOrdersView()
                    case .newWorkOrder:
                        NewWorkOrderView()
                    case .settings:
                        SettingsView()
                    case .customers:
                        CustomersView()
                    @unknown default:
                        Text("⚠️ Unknown AppScreen state")
                    }
                }
            }
            .id(appState.currentView) // Force recreation when app state changes
            .onAppear {
                print("🔍 RouterView detail area showing: \(appState.currentView)")
            }
            .onChange(of: appState.currentView) { _, newView in
                print("🔄 RouterView detail area switching to: \(newView)")
            }
        }
        // ───── END Split View Shell ─────
    }

}
// END struct

// ───── Preview Template ─────
#Preview {
    RouterView().environmentObject(AppState.shared)
}
