//
//  WorkOrder.swift
//  HydraulicsWorkOrderApp
//
//  Restored + backward-compatible model
//

// ─────────────────────────────────────────────────────────────
// 📄 WorkOrder.swift
// Core model for Work Orders in HydraulicsWorkOrderApp
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
    
    // Customer snapshot (stored for fast display)
    var customerId: String                    // Firebase doc ID
    var customerName: String                  // Snapshot for display
    var customerPhone: String                 // Snapshot for display (legacy fallback from phoneNumber)
    
    var WO_Type: String                       // Cylinder, Pump, etc.
    var imageURL: String?                     // First image preview (legacy)
    var imageURLs: [String] = []              // All full-size images (if present) – safe default for legacy docs
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
    var dropdownSchemaVersion: Int            // For backward compatibility

    // ───── Last Updated Info ─────
    var lastModified: Date
    var lastModifiedBy: String

    // ───── Audit & Extras ─────
    var tagBypassReason: String?
    var isDeleted: Bool

    // ───── Nested Arrays ─────
    var notes: [WO_Note]
    var items: [WO_Item]

    // ───── CodingKeys ─────
    enum CodingKeys: String, CodingKey {
        case createdBy

        case customerId
        case customerName
        case customerPhone        // current
        case phoneNumber          // legacy fallback

        case WO_Type
        case imageURL
        case imageURLs
        case timestamp
        case status
        case WO_Number
        case flagged

        case tagId
        case estimatedCost
        case finalCost

        case dropdowns
        case dropdownSchemaVersion

        case lastModified
        case lastModifiedBy

        case tagBypassReason
        case isDeleted

        case notes
        case items
    }

    // ───── Backward-Compatible Decoder ─────
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.createdBy  = try c.decode(String.self, forKey: .createdBy)

        // Customer fields — tolerate legacy shapes
        self.customerId    = try c.decodeIfPresent(String.self, forKey: .customerId) ?? ""
        self.customerName  = try c.decodeIfPresent(String.self, forKey: .customerName) ?? ""
        if let phone = try c.decodeIfPresent(String.self, forKey: .customerPhone) {
            self.customerPhone = phone
        } else {
            // legacy key
            self.customerPhone = try c.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        }

        self.WO_Type    = try c.decodeIfPresent(String.self, forKey: .WO_Type) ?? ""
        
        // ───── Image URL(s) – Backward compatible ─────
        // Accept: imageURLs (current), imageUrls (legacy-casing), or single imageURL
        struct _DynKey: CodingKey {
            var stringValue: String
            var intValue: Int?
            init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
            init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
        }
        
        let raw = try decoder.container(keyedBy: _DynKey.self)
        // 1) Current plural array
        let urlsCurrent = try raw.decodeIfPresent([String].self, forKey: _DynKey(stringValue: "imageURLs")!)
        // 2) Legacy plural array with different casing
        let urlsLegacy  = try raw.decodeIfPresent([String].self, forKey: _DynKey(stringValue: "imageUrls")!)
        // 3) Single preview image (legacy)
        let singleURL   = try c.decodeIfPresent(String.self, forKey: .imageURL)
        
        self.imageURL = singleURL
        if let arr = urlsCurrent, !arr.isEmpty {
            self.imageURLs = arr
        } else if let arr = urlsLegacy, !arr.isEmpty {
            self.imageURLs = arr
        } else if let one = singleURL {
            self.imageURLs = [one]
        } else {
            self.imageURLs = []
        }
        // ───── END image URL(s) decode ─────
        
        self.timestamp  = try c.decodeIfPresent(Date.self,   forKey: .timestamp) ?? Date()
        self.status     = try c.decodeIfPresent(String.self, forKey: .status) ?? "Checked In"
        self.WO_Number  = try c.decodeIfPresent(String.self, forKey: .WO_Number) ?? ""
        self.flagged    = try c.decodeIfPresent(Bool.self,   forKey: .flagged) ?? false

        self.tagId         = try c.decodeIfPresent(String.self, forKey: .tagId)
        self.estimatedCost = try c.decodeIfPresent(String.self, forKey: .estimatedCost)
        self.finalCost     = try c.decodeIfPresent(String.self, forKey: .finalCost)

        self.dropdowns             = try c.decodeIfPresent([String:String].self, forKey: .dropdowns) ?? [:]
        self.dropdownSchemaVersion = try c.decodeIfPresent(Int.self, forKey: .dropdownSchemaVersion) ?? 1

        // If legacy docs don’t have lastModified, fall back to timestamp
        self.lastModified   = try c.decodeIfPresent(Date.self, forKey: .lastModified) ?? self.timestamp
        self.lastModifiedBy = try c.decodeIfPresent(String.self, forKey: .lastModifiedBy) ?? self.createdBy

        self.tagBypassReason = try c.decodeIfPresent(String.self, forKey: .tagBypassReason)
        self.isDeleted       = try c.decodeIfPresent(Bool.self,   forKey: .isDeleted) ?? false

        self.notes = try c.decodeIfPresent([WO_Note].self, forKey: .notes) ?? []
        self.items = try c.decodeIfPresent([WO_Item].self, forKey: .items) ?? []
    }
    // END

    // ───── Encodable (manual) ─────
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        // Do NOT encode `id` — Firestore manages @DocumentID on write
        try c.encode(createdBy, forKey: .createdBy)

        try c.encode(customerId,   forKey: .customerId)
        try c.encode(customerName, forKey: .customerName)
        try c.encode(customerPhone, forKey: .customerPhone)

        try c.encode(WO_Type,   forKey: .WO_Type)
        try c.encodeIfPresent(imageURL, forKey: .imageURL)
        if !imageURLs.isEmpty {
            try c.encode(imageURLs, forKey: .imageURLs)
        }
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(status,    forKey: .status)
        try c.encode(WO_Number, forKey: .WO_Number)
        try c.encode(flagged,   forKey: .flagged)

        try c.encodeIfPresent(tagId,         forKey: .tagId)
        try c.encodeIfPresent(estimatedCost, forKey: .estimatedCost)
        try c.encodeIfPresent(finalCost,     forKey: .finalCost)

        try c.encode(dropdowns,             forKey: .dropdowns)
        try c.encode(dropdownSchemaVersion, forKey: .dropdownSchemaVersion)

        try c.encode(lastModified,   forKey: .lastModified)
        try c.encode(lastModifiedBy, forKey: .lastModifiedBy)

        try c.encodeIfPresent(tagBypassReason, forKey: .tagBypassReason)
        try c.encode(isDeleted, forKey: .isDeleted)

        try c.encode(notes, forKey: .notes)
        try c.encode(items, forKey: .items)
    }

    // ───── Memberwise init (used by previews & manual construction) ─────
    init(
        id: String? = nil,
        createdBy: String,
        customerId: String,
        customerName: String,
        customerPhone: String,
        WO_Type: String,
        imageURL: String? = nil,
        imageURLs: [String] = [],
        timestamp: Date,
        status: String,
        WO_Number: String,
        flagged: Bool,
        tagId: String? = nil,
        estimatedCost: String? = nil,
        finalCost: String? = nil,
        dropdowns: [String: String],
        dropdownSchemaVersion: Int,
        lastModified: Date,
        lastModifiedBy: String,
        tagBypassReason: String? = nil,
        isDeleted: Bool,
        notes: [WO_Note],
        items: [WO_Item]
    ) {
        self.id = id
        self.createdBy = createdBy
        self.customerId = customerId
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.WO_Type = WO_Type
        self.imageURL = imageURL
        self.imageURLs = imageURLs
        self.timestamp = timestamp
        self.status = status
        self.WO_Number = WO_Number
        self.flagged = flagged
        self.tagId = tagId
        self.estimatedCost = estimatedCost
        self.finalCost = finalCost
        self.dropdowns = dropdowns
        self.dropdownSchemaVersion = dropdownSchemaVersion
        self.lastModified = lastModified
        self.lastModifiedBy = lastModifiedBy
        self.tagBypassReason = tagBypassReason
        self.isDeleted = isDeleted
        self.notes = notes
        self.items = items
    }
    // END manual Encodable + memberwise init
}

// MARK: - Sample Data for Previews

extension WorkOrder {
    static let sample = WorkOrder(
        id: "preview-WO001",
        createdBy: "Maria",
        customerId: "sample-id",
        customerName: "Maria Rivera",
        customerPhone: "555-1234",
        WO_Type: "Cylinder",
        imageURL: nil,
        imageURLs: [],
        timestamp: Date(),
        status: "Checked In",
        WO_Number: "250820-001",
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
