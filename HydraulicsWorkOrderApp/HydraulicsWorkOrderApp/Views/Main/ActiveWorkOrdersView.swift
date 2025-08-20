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

    // Use explicit per-column spacing + a sensible minimum width to prevent overlap on iPad
    let columns = [
        GridItem(.flexible(minimum: 320), spacing: 24, alignment: .top),
        GridItem(.flexible(minimum: 320), spacing: 24, alignment: .top)
    ]

    var body: some View {
        NavigationSplitView(columnVisibility: $appState.splitVisibility) {
            // ───── Sidebar Content ─────
            SidebarMenuView() // Persistent sidebar
        } detail: {
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
                    
                    LazyVGrid(columns: columns, alignment: .center, spacing: 24) {
                        // ───── Data Source: Active only, sorted (flagged first, then oldest → newest) ─────
                        ForEach(active, id: \.id) { wo in
                            NavigationLink {

                                // ───── Detail with Delete wiring ─────
                                WorkOrderDetailView(workOrder: wo) { target in
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
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .navigationTitle("Active Work Orders")

                // ───── Toolbar (local, iOS‑17‑safe) ─────
                .modifier(ActiveWO_ToolbarModifier())
                // ───── END toolbar ─────



                // ───── Initial load / refresh / alerts ─────
                .task { await loadWorkOrders() }
                .refreshable { await loadWorkOrders() }
                .alert("Delete Failed", isPresented: $showError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                // ───── END misc modifiers ─────
            }
        }
        
    }
    // END NavigationSplitView
    // END body

// END body

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
// ───── Local Toolbar Modifier (keeps compiler happy, hides system toggle on iOS 17+) ─────
private struct ActiveWO_ToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
   

                // Right: + New Work Order (LEAVE THIS THE FUCK ALONE)
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
            .applySidebarRemovalIfAvailable()
    }
}

// Availability-safe removal of the auto-injected blue system toggle
private extension View {
    @ViewBuilder
    func applySidebarRemovalIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }
}

// Extension for NavigationSplitView specifically
private extension View {
    @ViewBuilder
    func applySidebarRemovalIfAvailableOnSplit() -> some View {
        if #available(iOS 17.0, *) {
            self.toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }
}
// ───── END Local Toolbar Helpers ─────

// ───── Preview Template ─────
#Preview(traits: .sizeThatFitsLayout) {
    ActiveWorkOrdersView()
        .environmentObject(AppState.shared)   // required for @EnvironmentObject AppState
}

