//
//  SampleDataLoader.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/12/25.
//


//
//  SampleDataLoader.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/12/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 SampleDataLoader.swift
// Dev-only loader for resetting WorkOrders, Customers, etc.
// ─────────────────────────────────────────────────────────────

import Foundation
import SwiftUI

final class SampleDataLoader {
    static let shared = SampleDataLoader()

    private init() {}

    // ───── Reset Sample Data ─────
    func reset() {
        print("🔄 SampleDataLoader: Resetting demo data...")

        // Placeholder:
        // Clear Firestore collections (if needed)
        // Inject sample WorkOrders, Customers, etc.

        // Example stubs:
        // WorkOrdersDatabase.shared.clearAll()
        // WorkOrdersDatabase.shared.seedWithMockData()
        // CustomerDatabase.shared.seedSampleCustomers()

        // You can also insert offline/local SQLite resets here
    }

    // END
}
