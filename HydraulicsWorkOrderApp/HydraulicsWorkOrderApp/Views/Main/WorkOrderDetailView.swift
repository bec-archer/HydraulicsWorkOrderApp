//
//  WorkOrderDetailView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderDetailView.swift
// Detail view for a selected WorkOrder
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct WorkOrderDetailView: View {
    let workOrder: WorkOrder

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("WO #\(workOrder.WO_Number)")
                    .font(.title)

                if workOrder.flagged {
                    Label("Flagged", systemImage: "flag.fill")
                        .foregroundColor(.red)
                }

                Text("Status: \(workOrder.status)")
                Text("Phone: \(workOrder.phoneNumber)")
                Text("Created: \(workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))")

                Divider()

                Text("Items:")
                    .font(.headline)

                ForEach(workOrder.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Type: \(item.type)")
                        if let tag = item.tagId {
                            Text("  Tag: \(tag)")
                        }
                        if let reason = item.reasonsForService.first {
                            Text("  Reason: \(reason)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Work Order Details")
        .navigationBarTitleDisplayMode(.inline)
        // END .body
    }
}

// ───── Preview Template ─────

#Preview {
    WorkOrderDetailView(workOrder: WorkOrder.sample)
}
