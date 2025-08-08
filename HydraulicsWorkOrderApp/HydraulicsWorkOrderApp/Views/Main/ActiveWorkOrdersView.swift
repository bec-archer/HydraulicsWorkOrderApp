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
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(db.workOrders.filter { !$0.isDeleted && $0.status != "Closed" }) { wo in
                        NavigationLink {
                            WorkOrderDetailView(workOrder: wo)
                        } label: {
                            WorkOrderCardView(workOrder: wo)
                        }
                    }

                }

                .padding()
            }
            .navigationTitle("Active Work Orders")
            .task {
                loadWorkOrders()
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
    func loadWorkOrders() {
        db.fetchAllWorkOrders { result in
            switch result {
            case .success:
                isLoading = false
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // END
}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    ActiveWorkOrdersView()
}
