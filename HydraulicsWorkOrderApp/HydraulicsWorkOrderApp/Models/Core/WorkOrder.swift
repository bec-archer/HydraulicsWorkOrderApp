//
//  WorkOrder.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 WorkOrder.swift
// Core model for Work Orders in HydraulicsCheckInApp
// ─────────────────────────────────────────────────────────────
import SwiftUI
import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - WorkOrder Model

struct WorkOrder: Identifiable, Codable, Equatable {
    
    // ───── Firestore Document ID ─────
    @DocumentID var id: String? // Auto-assigned by Firestore

    // ───── Core Metadata ─────
    var createdBy: String                     // Logged-in user's name
    var phoneNumber: String                   // For lookup and display
    var WO_Type: String                       // Cylinder, Pump, etc.
    var imageURL: String?                     // First image preview
    var timestamp: Date                       // Initial check-in time
    var status: String                        // Checked In, In Progress, etc.
    var WO_Number: String                     // Format: YYMMDD-001
    var flagged: Bool                         // Flag for follow-up

    // ───── Optional Tags / Cost Info ─────
    var tagId: String?
    var estimatedCost: String?
    var finalCost: String?

    // ───── Dropdown Snapshot ─────
    var dropdowns: [String: String]           // Frozen at creation
    var dropdownSchemaVersion: Int           // For backward compatibility

    // ───── Last Updated Info ─────
    var lastModified: Date
    var lastModifiedBy: String

    // ───── Audit & Extras ─────
    var tagBypassReason: String?
    var isDeleted: Bool

    // ───── Nested Arrays ─────
    var notes: [WO_Note]
    var items: [WO_Item]

    // END
}

// MARK: - Sample Data for Previews

extension WorkOrder {
    static let sample = WorkOrder(
        id: "preview-WO001",
        createdBy: "Maria",
        phoneNumber: "555-1234",
        WO_Type: "Cylinder",
        imageURL: nil,
        timestamp: Date(),
        status: "Checked In",
        WO_Number: "080824-001",
        flagged: true,
        tagId: "QR-ABC123",
        estimatedCost: "$200",
        finalCost: nil,
        dropdowns: [
            "Machine Brand": "Bobcat",
            "Machine Type": "Skid Steer"
        ],
        dropdownSchemaVersion: 1,
        lastModified: Date(),
        lastModifiedBy: "Maria",
        tagBypassReason: nil,
        isDeleted: false,
        notes: [],
        items: []
    )
}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading) {
        Text("WorkOrder Preview")
            .font(.title2)
        Text("WO_Number: \(WorkOrder.sample.WO_Number)")
        Text("Status: \(WorkOrder.sample.status)")
        Text("By: \(WorkOrder.sample.createdBy)")
    }
    .padding()
}
