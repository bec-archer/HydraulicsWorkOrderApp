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
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""

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
                            WorkOrderDetailView(workOrder: wo)
                        } label: {
                            WorkOrderCardView(workOrder: wo)
                        }
                    }
                    // END data source

                }

                .padding()
            }
            .navigationTitle("Active Work Orders")
            // ───── Initial load ─────
            .task {
                await loadWorkOrders()
            }
            // ───── Pull to refresh ─────
            .refreshable {
                await loadWorkOrders()
            }
            .alert("Error", isPresented: $showError) {

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
