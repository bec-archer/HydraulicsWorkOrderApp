//
//  DeletedWorkOrdersView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//


// ───── DELETED WORK ORDERS VIEW ─────
import SwiftUI

/// Admin/SuperAdmin-only view for managing deleted WorkOrders.
/// In future, this will fetch deleted docs from Firestore/SQLite and allow restore/permanent delete.
struct DeletedWorkOrdersView: View {
    @EnvironmentObject var appState: AppState

    // TODO: Replace with actual deleted WOs from WorkOrdersDatabase
    @State private var deletedOrders: [String] = [
        "082525-001", "082425-003" // stub WO numbers
    ]

    var body: some View {
        // ───── BODY ─────
        NavigationStack {
            List {
                if deletedOrders.isEmpty {
                    Text("No deleted Work Orders")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(deletedOrders, id: \.self) { wo in
                        HStack {
                            Text("WO \(wo)")
                            Spacer()
                            Button("Restore") {
                                // TODO: hook restore logic
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Delete") {
                                // TODO: hook permanent delete logic
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }
            }
            .navigationTitle("Deleted Work Orders")
        }
        // END
    }
}

// ───── PREVIEW ─────
#Preview {
    let s = AppState.previewLoggedIn(role: .superadmin)
    DeletedWorkOrdersView()
        .environmentObject(s)
}
// END