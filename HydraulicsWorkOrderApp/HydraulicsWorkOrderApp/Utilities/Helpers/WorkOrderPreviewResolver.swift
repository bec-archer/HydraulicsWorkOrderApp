//
//  WorkOrderPreviewResolver.swift
//  HydraulicsWorkOrderApp
//
//  Selects the best preview image URL string for a WorkOrder card/list entry.
//  Rule: first image becomes the card thumbnail (global behavior).
//
//  Created by Bec Archer on 8/21/25.
//

import Foundation

// ─────────────────────────────────────────────────────────────
// 🔎 WorkOrderPreviewResolver
// Central place to pick the thumbnail candidate for any WorkOrder
// ─────────────────────────────────────────────────────────────
struct WorkOrderPreviewResolver {

    // ───── Best Candidate (String) ─────
    /// Returns the best non-empty URL string candidate for a WorkOrder preview.
    /// Order:
    /// 1) Top-level imageURL (most up-to-date)
    /// 2) First WO_Item thumb
    /// 3) First WO_Item full
    /// 4) Legacy plural first (older docs)
    static func bestCandidate(from workOrder: WorkOrder) -> String? {
        let top       = workOrder.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemThumb = workOrder.items.first?.thumbUrls.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemFull  = workOrder.items.first?.imageUrls.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let legacy    = workOrder.imageURLs?.first?.trimmingCharacters(in: .whitespacesAndNewlines)

        #if DEBUG
        print("🔍 WorkOrderPreviewResolver for WO \(workOrder.WO_Number):")
        print("  - items.count: \(workOrder.items.count)")
        if let firstItem = workOrder.items.first {
            print("  - firstItem.thumbUrls.count: \(firstItem.thumbUrls.count)")
            print("  - firstItem.imageUrls.count: \(firstItem.imageUrls.count)")
            print("  - top: \(top ?? "nil")")
            print("  - itemThumb: \(itemThumb ?? "nil")")
            print("  - itemFull: \(itemFull ?? "nil")")
            print("  - legacy: \(legacy ?? "nil")")
        } else {
            print("  - No items found!")
        }
        #endif

        return [top, itemFull, itemThumb, legacy]
            .compactMap { $0 }
            .first { !$0.isEmpty }
    }
}
// END

// ───── Convenience Accessor on WorkOrder ─────
extension WorkOrder {
    /// Shared accessor used by views that need a preview image string.
    var preferredPreviewURLString: String? {
        WorkOrderPreviewResolver.bestCandidate(from: self)
    }
}
// END

// ───── Preview Template ─────
#if DEBUG
import SwiftUI
#Preview("Resolver Smoke Test") {
    VStack(alignment: .leading, spacing: 8) {
        Text("WorkOrderPreviewResolver ready")
            .font(.headline)
        Text("Hooked up in CardView, SearchView, etc.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
}
#endif
// END
