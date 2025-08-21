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
    /// 1) Legacy plural first (older docs)
    /// 2) First WO_Item thumb
    /// 3) First WO_Item full
    /// 4) Top-level imageURL
    static func bestCandidate(from workOrder: WorkOrder) -> String? {
        let top       = workOrder.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let legacy    = workOrder.imageURLs?.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemThumb = workOrder.items.first?.thumbUrls.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemFull  = workOrder.items.first?.imageUrls.first?.trimmingCharacters(in: .whitespacesAndNewlines)

        return [legacy, itemThumb, itemFull, top]
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
