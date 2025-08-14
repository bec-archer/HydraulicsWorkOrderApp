//
//  ActiveWorkOrdersView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 ActiveWorkOrdersView.swift
// Shows a grid of active WorkOrders from Firestore
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct ActiveWorkOrdersView: View {
    @ObservedObject var db = WorkOrdersDatabase.shared
    @EnvironmentObject private var appState: AppState
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""

    // ───── Sidebar Sheet State ─────
    @State private var showSidebar = false
    // END state

    // ───── Settings Sheet State ─────
    @State private var showSettings = false
    // END state

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                // ───── Loading / Empty States ─────
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading Active WorkOrders…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.top, 32)
                }

                let active = db.workOrders
                    .filter { !$0.isDeleted && $0.status != "Closed" }
                    .sorted {
                        if $0.flagged != $1.flagged { return $0.flagged && !$1.flagged }
                        return $0.timestamp < $1.timestamp
                    }

                if !isLoading && active.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Active WorkOrders")
                            .font(.headline)
                        Text("Tap + New to check one in.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.top, 32)
                }
                // ───── END Loading / Empty States ─────

                LazyVGrid(columns: columns, spacing: 16) {

                    // ───── Data Source: Active only, sorted (flagged first, then oldest → newest) ─────
                    let active = db.workOrders
                        .filter { !$0.isDeleted && $0.status != "Closed" }
                        .sorted {
                            // Flagged first
                            if $0.flagged != $1.flagged { return $0.flagged && !$1.flagged }
                            // Then oldest → newest by timestamp
                            return $0.timestamp < $1.timestamp
                        }
                    ForEach(active) { wo in
                        NavigationLink {
                            // ───── Detail with Delete wiring ─────
                            WorkOrderDetailView(workOrder: wo) { target in
                                // Bypass login is on during dev — use appState.currentUserName (can be blank)
                                WorkOrdersDatabase.shared.softDelete(target, by: appState.currentUserName) { result in
                                    switch result {
                                    case .success:
                                        break // The detail view will dismiss itself after calling this
                                    case .failure(let err):
                                        errorMessage = err.localizedDescription
                                        showError = true
                                    }
                                }
                            }
                            // END delete wiring
                        } label: {
                            WorkOrderCardView(workOrder: wo)
                        }
                    }


                    // END data source

                }

                .padding()
            }
            .navigationTitle("Active Work Orders")

            // ───── Top Bar: Sidebar (left) + New Work Order (right) ─────
            .toolbar {

                // Left: Sidebar (hamburger)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSidebar = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3.weight(.semibold))
                            .padding(8) // larger tap target
                            .background(Color.yellow.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel("Open Sidebar")
                    .buttonStyle(.plain)
                }

                // Right: + New Work Order (existing)
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        NewWorkOrderView()
                    } label: {
                        Text("+ New Work Order")
                            .modifier(UIConstants.Buttons.yellowButtonStyle())
                    }
                    .buttonStyle(.plain)
                }
            }
            // ───── END toolbar ─────

            // ───── END toolbar ─────

            // ───── Settings Sheet ─────
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .tint(Color("AppleNotesYellow")) // uses your theme if defined
            }
            // ───── END Settings Sheet ─────

            // ───── Sidebar Sheet ─────
            .sheet(isPresented: $showSidebar) {
                NavigationStack {
                    List {
                        // MAIN
                        Section("Main") {
                            Button {
                                appState.currentView = .activeWorkOrders
                                showSidebar = false
                            } label: {
                                Label("Active WorkOrders", systemImage: "square.grid.2x2")
                            }

                            Button {
                                appState.currentView = .newWorkOrder
                                showSidebar = false
                            } label: {
                                Label("New Work Order", systemImage: "plus.square.on.square")
                            }
                        }

                        // ADMIN / DEV
                        Section("Admin & Tools") {
                            Button {
                                appState.currentView = .settings
                                showSidebar = false
                            } label: {
                                Label("Settings", systemImage: "gearshape.fill")
                            }

                            // Placeholders (disabled until those screens exist)
                            Label("Customers (coming soon)", systemImage: "person.2")
                                .foregroundStyle(.secondary)
                            Label("Dropdown Manager (coming soon)", systemImage: "chevron.down.square")
                                .foregroundStyle(.secondary)
                            Label("Deleted WorkOrders (coming soon)", systemImage: "trash")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("Sidebar")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { showSidebar = false }
                        }
                    }
                    .tint(Color("AppleNotesYellow")) // project theme accent
                }
            }
            // ───── END Sidebar Sheet ─────

            // ───── Initial load ─────

            .task {

                await loadWorkOrders()
            }
            // ───── Pull to refresh ─────
            .refreshable {
                await loadWorkOrders()
            }
            .alert("Delete Failed", isPresented: $showError) {

                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        // END .body
    }

    // ───── Load WorkOrders from Firestore ─────
    func loadWorkOrders() async {
        isLoading = true
        await withCheckedContinuation { cont in
            db.fetchAllWorkOrders { result in
                switch result {
                case .success(_): // ignore the array payload; we already update via db.workOrders
                    isLoading = false
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
                cont.resume()
            }

        }
    }
    // END

}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    ActiveWorkOrdersView()
}
