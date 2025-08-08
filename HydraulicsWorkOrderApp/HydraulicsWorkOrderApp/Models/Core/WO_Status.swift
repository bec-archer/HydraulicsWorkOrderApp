//
//  WO_Satus.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 WO_Status.swift
// Represents a status update in a WO_Item timeline
// ─────────────────────────────────────────────────────────────

import Foundation
import FirebaseFirestoreSwift

// MARK: - WO_Status Model

struct WO_Status: Codable, Equatable {
    var status: String            // e.g., "In Progress", "Completed"
    var user: String              // Who changed it
    var timestamp: Date           // When it was updated
    var notes: String?            // Optional notes

    // END
}

// MARK: - Sample

extension WO_Status {
    static let sample = WO_Status(
        status: "In Progress",
        user: "Joe",
        timestamp: Date(),
        notes: "Started teardown"
    )
}
