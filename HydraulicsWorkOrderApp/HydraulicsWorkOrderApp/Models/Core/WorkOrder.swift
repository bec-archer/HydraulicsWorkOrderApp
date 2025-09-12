//
//  WorkOrder.swift
//  HydraulicsWorkOrderApp
//
//  Core WorkOrder model – Core Data first, with consistent naming.
//  NOTE: All fields now use consistent camelCase naming.
//
import SwiftUI
import Foundation

// ─────────────────────────────────────────────────────────────
// 📄 WorkOrder.swift
// Core model for Work Orders in HydraulicsWorkOrderApp
// ─────────────────────────────────────────────────────────────
struct WorkOrder: Identifiable, Codable, Equatable, Hashable {

    // ───── Core Metadata ─────
    var id: String = UUID().uuidString                    // Unique identifier
    var createdBy: String                                // Logged-in user's name

    // Customer snapshot (stored for fast display)
    var customerId: String                               // Customer reference ID
    var customerName: String                             // Snapshot for display
    var customerCompany: String?                         // Snapshot for display (optional)
    var customerEmail: String?                           // Snapshot for display (optional)
    var customerTaxExempt: Bool                          // Snapshot for display
    var customerPhone: String                            // Snapshot for display
    var customerEmojiTag: String?                        // Snapshot for display (optional)

    var workOrderType: String                            // Cylinder, Pump, etc. (renamed from WO_Type)

    // Single preview URL used by cards / lists
    var primaryImageURL: String?                         // e.g., first WO_Item thumb (renamed from imageURL)

    var timestamp: Date                                  // Initial check-in time
    var status: String                                   // Checked In, In Progress, etc.
    var workOrderNumber: String                          // Format: YYMMDD-001 (renamed from WO_Number)
    var flagged: Bool                                    // Flag for follow-up

    // ───── Optional Tags / Cost Info ─────
    var assetTagId: String?
    var estimatedCost: String?
    var finalCost: String?

    // ───── Dropdown Snapshot ─────
    var dropdowns: [String: String]                      // Frozen at creation
    var dropdownSchemaVersion: Int                       // For backward compatibility

    // ───── Last Updated Info ─────
    var lastModified: Date
    var lastModifiedBy: String

    // ───── Audit & Extras ─────
    var tagBypassReason: String?
    var isDeleted: Bool

    // ───── Sync Status ─────
    var syncStatus: String = "pending"                    // pending, syncing, synced, failed
    var lastSyncDate: Date?                              // When last synced to Firebase

    // ───── Nested Arrays ─────
    var notes: [WO_Note]
    var items: [WO_Item]

    // ───── Convenience: Derived Thumbnail (String) ─────
    /// Resolves the best thumbnail URL string for card display.
    /// Priority: WorkOrder.primaryImageURL → first WO_Item.thumbUrls → first WO_Item.imageUrls.
    var computedThumbnail: String? {
        // 1) New schema: single preview on WorkOrder
        if let s = primaryImageURL, !s.isEmpty { return s }
        // 2) Fallback to first WO_Item thumb, then full image
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

    // ───── CodingKeys ─────
    enum CodingKeys: String, CodingKey {
        case id
        case createdBy
        case customerId
        case customerName
        case customerCompany
        case customerEmail
        case customerTaxExempt
        case customerPhone
        case customerEmojiTag
        case workOrderType
        case primaryImageURL
        case timestamp
        case status
        case workOrderNumber
        case flagged
        case assetTagId
        case estimatedCost
        case finalCost
        case dropdowns
        case dropdownSchemaVersion
        case lastModified
        case lastModifiedBy
        case tagBypassReason
        case isDeleted
        case syncStatus
        case lastSyncDate
        case notes
        case items
    }

    // ───── Initializers ─────
    init(
        id: String = UUID().uuidString,
        createdBy: String,
        customerId: String,
        customerName: String,
        customerCompany: String?,
        customerEmail: String?,
        customerTaxExempt: Bool,
        customerPhone: String,
        customerEmojiTag: String? = nil,
        workOrderType: String,
        primaryImageURL: String?,
        timestamp: Date,
        status: String,
        workOrderNumber: String,
        flagged: Bool,
        assetTagId: String?,
        estimatedCost: String?,
        finalCost: String?,
        dropdowns: [String: String],
        dropdownSchemaVersion: Int,
        lastModified: Date,
        lastModifiedBy: String,
        tagBypassReason: String?,
        isDeleted: Bool,
        syncStatus: String = "pending",
        lastSyncDate: Date? = nil,
        notes: [WO_Note],
        items: [WO_Item]
    ) {
        self.id = id
        self.createdBy = createdBy
        self.customerId = customerId
        self.customerName = customerName
        self.customerCompany = customerCompany
        self.customerEmail = customerEmail
        self.customerTaxExempt = customerTaxExempt
        self.customerPhone = customerPhone
        self.customerEmojiTag = customerEmojiTag
        self.workOrderType = workOrderType
        self.primaryImageURL = primaryImageURL
        self.timestamp = timestamp
        self.status = status
        self.workOrderNumber = workOrderNumber
        self.flagged = flagged
        self.assetTagId = assetTagId
        self.estimatedCost = estimatedCost
        self.finalCost = finalCost
        self.dropdowns = dropdowns
        self.dropdownSchemaVersion = dropdownSchemaVersion
        self.lastModified = lastModified
        self.lastModifiedBy = lastModifiedBy
        self.tagBypassReason = tagBypassReason
        self.isDeleted = isDeleted
        self.syncStatus = syncStatus
        self.lastSyncDate = lastSyncDate
        self.notes = notes
        self.items = items
    }

    // ───── Convenience Initializer ─────
    init() {
        self.id = UUID().uuidString
        self.createdBy = ""
        self.customerId = ""
        self.customerName = ""
        self.customerCompany = nil
        self.customerEmail = nil
        self.customerTaxExempt = false
        self.customerPhone = ""
        self.customerEmojiTag = nil
        self.workOrderType = ""
        self.primaryImageURL = nil
        self.timestamp = Date()
        self.status = ""
        self.workOrderNumber = ""
        self.flagged = false
        self.assetTagId = nil
        self.estimatedCost = nil
        self.finalCost = nil
        self.dropdowns = [:]
        self.dropdownSchemaVersion = 1
        self.lastModified = Date()
        self.lastModifiedBy = ""
        self.tagBypassReason = nil
        self.isDeleted = false
        self.syncStatus = "pending"
        self.lastSyncDate = nil
        self.notes = []
        self.items = []
    }
    
    static var sample: WorkOrder {
        WorkOrder(
            id: UUID().uuidString,
            createdBy: "Sample User",
            customerId: UUID().uuidString,
            customerName: "Sample Customer",
            customerCompany: "Sample Company",
            customerEmail: "sample@example.com",
            customerTaxExempt: false,
            customerPhone: "555-123-4567",
            workOrderType: "Sample Type",
            primaryImageURL: "https://picsum.photos/400",
            timestamp: Date(),
            status: "Checked In",
            workOrderNumber: "SAMPLE-WO-001",
            flagged: false,
            assetTagId: "SAMPLE-TAG",
            estimatedCost: "500.00",
            finalCost: nil,
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            lastModified: Date(),
            lastModifiedBy: "Sample User",
            tagBypassReason: nil,
            isDeleted: false,
            syncStatus: "pending",
            lastSyncDate: nil,
            notes: [],
            items: []
        )
    }
}

// ───── Extensions ─────
extension WorkOrder {
    
    // ───── Validation ─────
    var isValid: Bool {
        !workOrderNumber.isEmpty &&
        !customerName.isEmpty &&
        !customerPhone.isEmpty &&
        !workOrderType.isEmpty &&
        !items.isEmpty
    }
    
    // ───── Computed Properties ─────
    var totalEstimatedCost: Decimal {
        items.compactMap { Decimal(string: $0.estimatedCost ?? "0") }.reduce(0, +)
    }
    
    var totalFinalCost: Decimal {
        items.compactMap { Decimal(string: $0.finalCost ?? "0") }.reduce(0, +)
    }
    
    var hasImages: Bool {
        !items.allSatisfy { $0.imageUrls.isEmpty && $0.thumbUrls.isEmpty }
    }
    
    var isComplete: Bool {
        // Check work order status first
        if status == "Done" || status == "Completed" || status == "Complete" {
            return true
        }
        
        // Also check if any items are complete (for cases where work order status isn't updated)
        return items.contains { item in
            let currentStatus = item.statusHistory.last?.status ?? ""
            return currentStatus.lowercased() == "complete"
        }
    }
    
    var isInProgress: Bool {
        status == "In Progress" || status == "Working"
    }
    
    var isCheckedIn: Bool {
        status == "Checked In"
    }
    
    var needsSync: Bool {
        syncStatus == "pending" || syncStatus == "failed"
    }
}

// ───── Equatable Implementation ─────
extension WorkOrder {
    static func == (lhs: WorkOrder, rhs: WorkOrder) -> Bool {
        lhs.id == rhs.id &&
        lhs.lastModified == rhs.lastModified
    }
}
