//
//  StatusBadge.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 StatusBadge.swift
// Color-coded badge for WorkOrder status
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status.lowercased() {
        case "checked in": return .green
        case "in progress": return .orange
        case "done": return .teal
        case "completed": return .gray
        default: return .secondary
        }
    }

    var body: some View {
        Text(status)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
