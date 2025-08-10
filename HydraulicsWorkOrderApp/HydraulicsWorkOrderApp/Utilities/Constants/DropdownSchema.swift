//
//  DropdownSchema.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/10/25.
//


//
//  DropdownSchema.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/10/25.
//

import SwiftUI
import Foundation

// ─────────────────────────────────────────────────────────────
// 📌 DropdownSchema
// Single source of truth for the current dropdown set version.
// Increment `currentVersion` whenever you change the dropdown
// options (add/remove/reorder) so existing WorkOrders/W0_Items
// keep their frozen version for compatibility.
// ─────────────────────────────────────────────────────────────
struct DropdownSchema {
    // 🔖 Bump this when admin-editable dropdowns are changed.
    static let currentVersion: Int = 1
}
// END: DropdownSchema


// ───── Preview Template ─────
// Light-weight preview just to satisfy our project-wide convention
#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 8) {
        Text("Dropdown Schema")
            .font(.title2)
        Text("Current Version: \(DropdownSchema.currentVersion)")
            .font(.headline)
    }
    .padding()
}
