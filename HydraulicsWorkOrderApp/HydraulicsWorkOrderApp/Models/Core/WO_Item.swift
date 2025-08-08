//
//  WO_Item.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//

// ─────────────────────────────────────────────────────────────
// 📄 WO_Item.swift
// Represents a single piece of equipment in a WorkOrder
// ─────────────────────────────────────────────────────────────
import SwiftUI
import Foundation
import FirebaseFirestoreSwift

// MARK: - WO_Item Model

struct WO_Item: Identifiable, Codable, Equatable {
    // ───── Unique Identifier ─────
    var id: UUID = UUID()

    // ───── Equipment Info ─────
    var tagId: String?                      // QR or RFID
    var imageUrls: [String]                 // Uploaded to Firebase Storage
    var type: String                        // Cylinder, Pump, Hose, etc.

    // ───── Dropdowns + Reason ─────
    var dropdowns: [String: String]         // Frozen at intake
    var dropdownSchemaVersion: Int
    var reasonsForService: [String]         // e.g., "Replace Seals"
    var reasonNotes: String?

    // ───── Status + Testing ─────
    var statusHistory: [WO_Status]          // Timeline entries
    var testResult: String?                 // PASS / FAIL / nil
    var partsUsed: String?
    var hoursWorked: String?
    var cost: String?

    // ───── Assignment + Flags ─────
    var assignedTo: String                  // Technician name
    var isFlagged: Bool

    // ───── Audit Trail ─────
    var tagReplacementHistory: [TagReplacement]?
}

// MARK: - Sample + Factory

extension WO_Item {
    static let sample = WO_Item(
        tagId: "QR-123456",
        imageUrls: [],
        type: "Cylinder",
        dropdowns: [
            "type": "Cylinder",
            "size": "< 24\"",
            "color": "Black",
            "machineType": "Forklift",
            "machineBrand": "Bobcat",
            "waitTime": "24 hrs"
        ],
        dropdownSchemaVersion: 1,
        reasonsForService: ["Replace Seals"],
        reasonNotes: "Leaking from top seal",
        statusHistory: [],
        testResult: nil,
        partsUsed: nil,
        hoursWorked: nil,
        cost: nil,
        assignedTo: "Maria",
        isFlagged: false,
        tagReplacementHistory: nil
    )

    static func empty() -> WO_Item {
        WO_Item(
            tagId: nil,
            imageUrls: [],
            type: "",
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            reasonsForService: [],
            reasonNotes: nil,
            statusHistory: [],
            testResult: nil,
            partsUsed: nil,
            hoursWorked: nil,
            cost: nil,
            assignedTo: "",
            isFlagged: false,
            tagReplacementHistory: nil
        )
    }
}

// ───── Preview Template ─────
#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading) {
        Text("WO_Item Preview")
            .font(.title2)
        Text("Assigned To: \(WO_Item.sample.assignedTo)")
    }
    .padding()
}
