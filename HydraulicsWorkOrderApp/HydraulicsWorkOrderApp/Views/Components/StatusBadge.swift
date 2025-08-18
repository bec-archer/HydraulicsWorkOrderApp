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
        case "checked in":   return UIConstants.StatusColors.checkedIn
        case "disassembly":  return UIConstants.StatusColors.disassembly
        case "in progress":  return UIConstants.StatusColors.inProgress
        case "test failed":  return UIConstants.StatusColors.testFailed
        case "completed":    return UIConstants.StatusColors.completed
        case "closed":       return UIConstants.StatusColors.closed
        default:             return UIConstants.StatusColors.fallback
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
