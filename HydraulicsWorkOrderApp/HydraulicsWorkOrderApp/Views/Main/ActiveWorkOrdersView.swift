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
    
    @State private var showSidebarSheet = false


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

            // ───── Toolbar: Sidebar (left) + New Work Order (right) ─────
            .toolbar {
                // Left: Sidebar button (hamburger)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // Open our custom sidebar sheet
                        showSidebarSheet = true
                    } label: {
                        // Large, legible tap target
                        Image(systemName: "line.3.horizontal")
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, 4)
                            .accessibilityLabel("Open Sidebar")
                    }
                }

                // Right: + New Work Order
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

            // ───── Sidebar Sheet Presentation ─────
            .sheet(isPresented: $showSidebarSheet) {
                SidebarMenuSheet()
                    .environmentObject(appState) // needed for routing out of the sheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
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
