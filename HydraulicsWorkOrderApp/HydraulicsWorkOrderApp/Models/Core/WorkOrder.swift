//
//  WorkOrder.swift
//  HydraulicsWorkOrderApp
//
//  Core WorkOrder model – Firestore-first, with backward-compatible image fields.
//  NOTE: Do not rename fields without updating Firestore + SQLite bindings.
//
import SwiftUI
import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// ─────────────────────────────────────────────────────────────
// 📄 WorkOrder.swift
// Core model for Work Orders in HydraulicsWorkOrderApp
// ─────────────────────────────────────────────────────────────
struct WorkOrder: Identifiable, Codable, Equatable {

    // ───── Firestore Document ID ─────
    @DocumentID var id: String? // Firestore doc id (string)

    // ───── Core Metadata ─────
    var createdBy: String                     // Logged-in user's name

    // Customer snapshot (stored for fast display)
    var customerId: String                    // Firebase doc ID
    var customerName: String                  // Snapshot for display
    var customerPhone: String                 // Snapshot for display (legacy fallback from phoneNumber)

    var WO_Type: String                       // Cylinder, Pump, etc.

    // New schema: single preview URL used by cards / lists
    var imageURL: String?                     // e.g., first WO_Item thumb

    // Legacy top-level array (older docs). New docs use `imageURL` (singular).
    // Keep optional so decode doesn’t fail when the key is missing.
    var imageURLs: [String]? = nil

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

    // ───── Convenience: Derived Thumbnail (String) ─────
    /// Resolves the best thumbnail URL string for card display.
    /// Priority: WorkOrder.imageURL → legacy imageURLs[0] → first WO_Item.thumbUrls → first WO_Item.imageUrls.
    var computedThumbnail: String? {
        // 1) New schema: single preview on WorkOrder
        if let s = imageURL, !s.isEmpty { return s }
        // 2) Legacy schema: first in top-level array
        if let s = imageURLs?.first, !s.isEmpty { return s }
        // 3) Fallback to first WO_Item thumb, then full image
        for item in items {
            if let s = item.thumbUrls.first, !s.isEmpty { return s }
            if let s = item.imageUrls.first, !s.isEmpty { return s }
        }
        return nil
    }

    // ───── Derived: Preview thumbnail URL (for cards) ─────
    /// URL-typed convenience built on top of `computedThumbnail`.
    var previewThumbURL: URL? {
        guard let s = computedThumbnail else { return nil }
        return URL(string: s)
    }
    // END Derived

    // ───── CodingKeys ─────
    enum CodingKeys: String, CodingKey {
        case createdBy

        case customerId
        case customerName
        case customerPhone        // current
        case phoneNumber          // legacy fallback

        case WO_Type
        case imageURL
        case imageURLs            // legacy array (optional)
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

        // ───── Image URL – Backward compatible only ─────
        self.imageURL  = try c.decodeIfPresent(String.self, forKey: .imageURL)
        self.imageURLs = try c.decodeIfPresent([String].self, forKey: .imageURLs)
        // ───── END image URL decode ─────

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
        try c.encodeIfPresent(imageURL,  forKey: .imageURL)
        try c.encodeIfPresent(imageURLs, forKey: .imageURLs)
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
        imageURLs: [String]? = nil,
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
// END WorkOrder

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
        imageURLs: nil,
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
