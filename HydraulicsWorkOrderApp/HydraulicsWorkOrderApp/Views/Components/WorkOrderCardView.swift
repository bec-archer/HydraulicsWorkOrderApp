//
//  WorkOrderCardView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderCardView.swift
// Reusable grid card for each WorkOrder
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct WorkOrderCardView: View {
    let workOrder: WorkOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ───── Image (placeholder for now) ─────
            Rectangle()
                .fill(Color(.systemGray5))
                .aspectRatio(4/3, contentMode: .fit)
                .overlay(
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                )

            // ───── Info Block ─────
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("WO \(workOrder.WO_Number)")
                        .font(.headline)
                    if workOrder.flagged {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(workOrder.customerName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(workOrder.customerPhone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }


                StatusBadge(status: workOrder.status)

                Text(workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    WorkOrderCardView(workOrder: WorkOrder.sample)
}
