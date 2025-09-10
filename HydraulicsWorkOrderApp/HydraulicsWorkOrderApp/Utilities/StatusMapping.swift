//
//  StatusMapping.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/9/25.
//

import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 StatusMapping.swift
// Status mapping logic for WorkOrderCardView indicator dots
// Implements the status resolution and color mapping per WO_Item
// ─────────────────────────────────────────────────────────────

struct StatusMapping {
    
    // MARK: - Status Resolution
    /// Resolves the current status for a WO_Item
    /// Priority: latest statusHistory > "Checked In"
    static func resolvedStatus(for item: WO_Item) -> String {
        // 1. Check latest statusHistory entry
        if let latestStatus = item.statusHistory
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first {
            return latestStatus.status
        }
        
        // 2. Fallback to "Checked In"
        return "Checked In"
    }
    
    // MARK: - Color Mapping
    /// Gets the color for a status, using the same semantic mapping as StatusBadge
    static func color(for status: String) -> Color {
        // Create a temporary StatusBadge to get the color
        let badge = StatusBadge(status: status)
        return badge.color
    }
    
    // MARK: - Work Order Item Statuses
    /// Gets the resolved statuses for the first 4 items in a work order
    static func itemStatuses(for workOrder: WorkOrder) -> [String] {
        return workOrder.items
            .prefix(4) // Limit to first 4 items
            .map { resolvedStatus(for: $0) }
    }
    
    // MARK: - Item Status with Color
    /// Combines status and color for easy use in UI
    struct ItemStatus {
        let status: String
        let color: Color
        
        init(for item: WO_Item) {
            self.status = StatusMapping.resolvedStatus(for: item)
            self.color = StatusMapping.color(for: self.status)
        }
    }
    
    /// Gets ItemStatus objects for the first 4 items
    static func itemStatusesWithColor(for workOrder: WorkOrder) -> [ItemStatus] {
        return workOrder.items
            .prefix(4)
            .map { ItemStatus(for: $0) }
    }
}

// MARK: - Indicator Dot Component
struct IndicatorDot: View {
    let color: Color
    let size: CGFloat
    
    init(color: Color, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Overlay Dot (for thumbnails)
struct OverlayDot: View {
    let color: Color
    let size: CGFloat
    
    init(color: Color, size: CGFloat = 10) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1)
            )
    }
}
