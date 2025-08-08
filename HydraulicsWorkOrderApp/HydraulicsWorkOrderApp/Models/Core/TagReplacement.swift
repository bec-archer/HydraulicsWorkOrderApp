//
//  TagReplacement.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 TagReplacement.swift
// Tracks when an RFID/QR tag was replaced on a WO_Item
// ─────────────────────────────────────────────────────────────

import Foundation
import FirebaseFirestoreSwift

// MARK: - TagReplacement Model

struct TagReplacement: Codable, Equatable {
    var oldTagId: String
    var newTagId: String
    var replacedBy: String
    var timestamp: Date
    var reason: String?           // Optional description of why

    // END
}

// MARK: - Sample

extension TagReplacement {
    static let sample = TagReplacement(
        oldTagId: "QR-ABC123",
        newTagId: "QR-XYZ789",
        replacedBy: "Maria",
        timestamp: Date(),
        reason: "Tag damaged"
    )
}
