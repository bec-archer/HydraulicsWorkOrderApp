import Foundation
import SwiftUI

struct WO_Item: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var itemNumber: String? = nil  // 🆕 Human-readable WO Item ID (e.g., "250826-653-WOI-001") (renamed from woItemId)
    var assetTagId: String? = nil  // 🆕 Asset tag ID (renamed from tagId)
    var type: String = ""
    
    // MARK: - Static Factory Method
    static func create() -> WO_Item {
        return WO_Item(
            id: UUID(),
            itemNumber: nil,  // Will be set when item is added to work order
            assetTagId: nil,
            type: "",
            imageUrls: [],
            thumbUrls: [],
            localImages: [],
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            reasonsForService: [],
            reasonNotes: nil,
            completedReasons: [],
            statusHistory: [],
            notes: [],
            testResult: nil,
            partsUsed: nil,
            hoursWorked: nil,
            estimatedCost: nil,
            finalCost: nil,
            assignedTo: "",
            isFlagged: false,
            tagReplacementHistory: nil
        )
    }

    var dropdowns: [String: String] = [:]
    var reasonsForService: [String] = []
    var reasonNotes: String? = nil
    var completedReasons: [String] = [] // Track which reasons have been completed

    var imageUrls: [String] = []
    var thumbUrls: [String] = []       // 🆕 store thumbnails for fast UI
    var localImages: [UIImage] = []    // ✅ No longer using @TransientImageStorage
    // 🆕 Store local images for offline use
    var lastModified: Date = Date()
    var dropdownSchemaVersion: Int = 1
    var lastModifiedBy: String? = nil

    // 🆕 Per‑item status updates (Checked In → In Progress → Done → …)
    var statusHistory: [WO_Status] = []

    // 🆕 Per‑item notes/timeline (free‑form + system status notes live together)
    var notes: [WO_Note] = []
      
    // 🆕 Preview/test fields (must match init)
    var testResult: String? = nil
    var partsUsed: String? = nil
    var hoursWorked: String? = nil
    var estimatedCost: String? = nil  // Renamed from cost for clarity
    var finalCost: String? = nil      // New field for final cost
    var assignedTo: String = ""
    var isFlagged: Bool = false
    var tagReplacementHistory: [TagReplacement]? = nil

    // MARK: - Memberwise Initializer
    init(
        id: UUID = UUID(),
        itemNumber: String? = nil,
        assetTagId: String? = nil,
        type: String = "",
        imageUrls: [String] = [],
        thumbUrls: [String] = [],
        localImages: [UIImage] = [],
        dropdowns: [String: String] = [:],
        dropdownSchemaVersion: Int = 1,
        reasonsForService: [String] = [],
        reasonNotes: String? = nil,
        completedReasons: [String] = [],
        statusHistory: [WO_Status] = [],
        notes: [WO_Note] = [],
        testResult: String? = nil,
        partsUsed: String? = nil,
        hoursWorked: String? = nil,
        estimatedCost: String? = nil,
        finalCost: String? = nil,
        assignedTo: String = "",
        isFlagged: Bool = false,
        tagReplacementHistory: [TagReplacement]? = nil,
        lastModified: Date = Date(),
        lastModifiedBy: String? = nil
    ) {
        self.id = id
        self.itemNumber = itemNumber
        self.assetTagId = assetTagId
        self.type = type
        self.imageUrls = imageUrls
        self.thumbUrls = thumbUrls
        self.localImages = localImages
        self.dropdowns = dropdowns
        self.dropdownSchemaVersion = dropdownSchemaVersion
        self.reasonsForService = reasonsForService
        self.reasonNotes = reasonNotes
        self.completedReasons = completedReasons
        self.statusHistory = statusHistory
        self.notes = notes
        self.testResult = testResult
        self.partsUsed = partsUsed
        self.hoursWorked = hoursWorked
        self.estimatedCost = estimatedCost
        self.finalCost = finalCost
        self.assignedTo = assignedTo
        self.isFlagged = isFlagged
        self.tagReplacementHistory = tagReplacementHistory
        self.lastModified = lastModified
        self.lastModifiedBy = lastModifiedBy
    }
    
    // MARK: - Convenience Initializer
    init() {
        self.id = UUID()
        self.itemNumber = nil
        self.assetTagId = nil
        self.type = ""
        self.imageUrls = []
        self.thumbUrls = []
        self.localImages = []
        self.dropdowns = [:]
        self.dropdownSchemaVersion = 1
        self.reasonsForService = []
        self.reasonNotes = nil
        self.completedReasons = []
        self.statusHistory = []
        self.notes = []
        self.testResult = nil
        self.partsUsed = nil
        self.hoursWorked = nil
        self.estimatedCost = nil
        self.finalCost = nil
        self.assignedTo = ""
        self.isFlagged = false
        self.tagReplacementHistory = nil
        self.lastModified = Date()
        self.lastModifiedBy = nil
    }

    // MARK: - Blank Item Factory
    static func blank() -> WO_Item {
        return WO_Item()
    }
    
    static var sample: WO_Item {
        WO_Item(
            id: UUID(),
            itemNumber: "SAMPLE-001",
            assetTagId: "SAMPLE-TAG",
            type: "Sample Item",
            imageUrls: ["https://picsum.photos/400"],
            thumbUrls: ["https://picsum.photos/100"],
            localImages: [],
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            reasonsForService: ["Sample reason"],
            reasonNotes: "Sample note",
            completedReasons: [],
            statusHistory: [
                WO_Status(status: "Checked In", user: "Sample User", timestamp: Date(), notes: nil)
            ],
            notes: [],
            testResult: "Sample result",
            partsUsed: "Sample parts",
            hoursWorked: "2.5",
            estimatedCost: "100.00",
            finalCost: "95.00",
            assignedTo: "Sample Tech",
            isFlagged: false,
            tagReplacementHistory: []
        )
    }
}

// Ignore localImages in Codable
extension WO_Item {
    enum CodingKeys: String, CodingKey {
        case id, itemNumber, assetTagId, type, dropdowns, reasonsForService, reasonNotes, completedReasons,
             imageUrls, thumbUrls, lastModified, dropdownSchemaVersion, lastModifiedBy,
             statusHistory, notes, testResult, partsUsed, hoursWorked, estimatedCost, finalCost, assignedTo, isFlagged, tagReplacementHistory
    }
}

// ───── Back-compat Codable init (defaults missing keys) ─────
extension WO_Item {
    init(from decoder: Decoder) throws {
        #if DEBUG
        print("🔍 DEBUG: WO_Item decoding started")
        #endif
        
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        #if DEBUG
        // Debug: Print all available keys
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let allKeys = container.allKeys
            print("🔍 Available keys in WO_Item: \(allKeys.map { $0.stringValue })")
        }
        #endif

        do {
            self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'id': \(error)")
            #endif
            throw error
        }

        // Handle legacy field names
        if let itemNumber = try? c.decodeIfPresent(String.self, forKey: .itemNumber) {
            self.itemNumber = itemNumber
        } else if let woItemId = try? c.decodeIfPresent(String.self, forKey: .itemNumber) {
            self.itemNumber = woItemId
        }

        if let assetTagId = try? c.decodeIfPresent(String.self, forKey: .assetTagId) {
            self.assetTagId = assetTagId
        } else if let tagId = try? c.decodeIfPresent(String.self, forKey: .assetTagId) {
            self.assetTagId = tagId
        }

        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.imageUrls = try c.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        self.thumbUrls = try c.decodeIfPresent([String].self, forKey: .thumbUrls) ?? []
        self.dropdowns = try c.decodeIfPresent([String: String].self, forKey: .dropdowns) ?? [:]
        self.dropdownSchemaVersion = try c.decodeIfPresent(Int.self, forKey: .dropdownSchemaVersion) ?? 1
        self.reasonsForService = try c.decodeIfPresent([String].self, forKey: .reasonsForService) ?? []
        self.reasonNotes = try c.decodeIfPresent(String.self, forKey: .reasonNotes)
        self.completedReasons = try c.decodeIfPresent([String].self, forKey: .completedReasons) ?? []
        self.statusHistory = try c.decodeIfPresent([WO_Status].self, forKey: .statusHistory) ?? []
        self.notes = try c.decodeIfPresent([WO_Note].self, forKey: .notes) ?? []
        self.testResult = try c.decodeIfPresent(String.self, forKey: .testResult)
        self.partsUsed = try c.decodeIfPresent(String.self, forKey: .partsUsed)
        self.hoursWorked = try c.decodeIfPresent(String.self, forKey: .hoursWorked)
        
        // Handle legacy cost field
        if let estimatedCost = try? c.decodeIfPresent(String.self, forKey: .estimatedCost) {
            self.estimatedCost = estimatedCost
        } else if let cost = try? c.decodeIfPresent(String.self, forKey: .estimatedCost) {
            self.estimatedCost = cost
        }
        
        self.finalCost = try c.decodeIfPresent(String.self, forKey: .finalCost)
        self.assignedTo = try c.decodeIfPresent(String.self, forKey: .assignedTo) ?? ""
        self.isFlagged = try c.decodeIfPresent(Bool.self, forKey: .isFlagged) ?? false
        self.tagReplacementHistory = try c.decodeIfPresent([TagReplacement].self, forKey: .tagReplacementHistory)
        self.lastModified = try c.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        self.lastModifiedBy = try c.decodeIfPresent(String.self, forKey: .lastModifiedBy)
        
        #if DEBUG
        print("✅ WO_Item decode successful: id=\(self.id), type='\(self.type)'")
        #endif
    }
}

// MARK: - Extensions
extension WO_Item {
    
    // MARK: - Validation
    var isValid: Bool {
        !type.isEmpty && !imageUrls.isEmpty && !reasonsForService.isEmpty
    }
    
    var hasImages: Bool {
        !imageUrls.isEmpty || !thumbUrls.isEmpty
    }
    
    var hasReasons: Bool {
        !reasonsForService.isEmpty
    }
    
    var isComplete: Bool {
        isValid && !isFlagged
    }
    
    // MARK: - Computed Properties
    var displayName: String {
        if let itemNumber = itemNumber {
            return "\(type) - \(itemNumber)"
        }
        return type
    }
    
    var totalCost: Decimal {
        let estimated = Decimal(string: estimatedCost ?? "0") ?? 0
        let final = Decimal(string: finalCost ?? "0") ?? 0
        return final > 0 ? final : estimated
    }
}

// MARK: - Equatable
extension WO_Item {
    static func == (lhs: WO_Item, rhs: WO_Item) -> Bool {
        lhs.id == rhs.id && lhs.lastModified == rhs.lastModified
    }
}
