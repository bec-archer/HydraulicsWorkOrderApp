//
//  PendingApprovalView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//


// ───── PENDING APPROVAL VIEW ─────
import SwiftUI

/// Manager-facing queue of items that need attention (e.g., PROBLEM CHILD, tag issues).
/// This is a scaffold; we'll wire real data from WorkOrdersDatabase / rules later.
struct PendingApprovalView: View {
    @EnvironmentObject var appState: AppState

    // TODO: Replace with real query: WO_Items flagged as "PROBLEM CHILD" or requiring manager attention.
    @State private var pendingItems: [String] = [
        "WO 090125-004 • Item A • PROBLEM CHILD",
        "WO 090125-012 • Item B • Tag mismatch"
    ]

    var body: some View {
        // ───── BODY ─────
        NavigationStack {
            List {
                if pendingItems.isEmpty {
                    Text("No items require manager review.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pendingItems, id: \.self) { row in
                        NavigationLink(row, destination: ManagerReviewView() // pass context later
                            .environmentObject(appState))
                    }
                }
            }
            .navigationTitle("Pending Approval")
        }
        // END
    }
}

// ───── PREVIEW ─────
#Preview {
    let s = AppState.previewLoggedIn(role: .manager)
    PendingApprovalView()
        .environmentObject(s)
}
// END