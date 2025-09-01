import Foundation
import SwiftUI

struct WO_Item: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var woItemId: String? = nil  // 🆕 Human-readable WO Item ID (e.g., "250826-653-WOI-001")
    var tagId: String? = nil
    var type: String = ""
    
    // MARK: - Static Factory Method
    static func create() -> WO_Item {
        return WO_Item(
            id: UUID(),
            woItemId: nil,  // Will be set when item is added to work order
            tagId: nil,
            imageUrls: [],
            thumbUrls: [],
            type: "",
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            reasonsForService: [],
            reasonNotes: nil,
            completedReasons: [],
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
    var cost: String? = nil
    var assignedTo: String = ""
    var isFlagged: Bool = false
    var tagReplacementHistory: [TagReplacement]? = nil


}

// Ignore localImages in Codable
extension WO_Item {
    enum CodingKeys: String, CodingKey {
        case id, woItemId, tagId, type, dropdowns, reasonsForService, reasonNotes, completedReasons,
             imageUrls, thumbUrls, lastModified, dropdownSchemaVersion, lastModifiedBy,
             statusHistory, notes, testResult, partsUsed, hoursWorked, cost, assignedTo, isFlagged, tagReplacementHistory
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
        
        do {
            self.woItemId = try c.decodeIfPresent(String.self, forKey: .woItemId)
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'woItemId': \(error)")
            #endif
            throw error
        }
        
        do {
            self.tagId = try c.decodeIfPresent(String.self, forKey: .tagId)
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'tagId': \(error)")
            #endif
            throw error
        }
        
        do {
            self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? "Cylinder"
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'type': \(error)")
            #endif
            throw error
        }

        do {
            self.dropdowns = try c.decodeIfPresent([String:String].self, forKey: .dropdowns) ?? [:]
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'dropdowns': \(error)")
            #endif
            throw error
        }
        
        do {
            self.reasonsForService = try c.decodeIfPresent([String].self, forKey: .reasonsForService) ?? []
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'reasonsForService': \(error)")
            #endif
            throw error
        }
        
        do {
            self.reasonNotes = try c.decodeIfPresent(String.self, forKey: .reasonNotes)
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'reasonNotes': \(error)")
            #endif
            throw error
        }
        
        do {
            self.completedReasons = try c.decodeIfPresent([String].self, forKey: .completedReasons) ?? []
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'completedReasons': \(error)")
            #endif
            throw error
        }

        // 🔑 Back-compat: default to [] when key missing
        do {
            self.imageUrls = try c.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'imageUrls': \(error)")
            #endif
            throw error
        }
        
        do {
            self.thumbUrls = try c.decodeIfPresent([String].self, forKey: .thumbUrls) ?? []
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'thumbUrls': \(error)")
            #endif
            throw error
        }
        
        // Standardized image handling - ensure imageUrls has data
        if self.imageUrls.isEmpty && !self.thumbUrls.isEmpty {
            self.imageUrls = self.thumbUrls
        }

        do {
            self.lastModified = try c.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'lastModified': \(error)")
            #endif
            throw error
        }
        
        do {
            self.dropdownSchemaVersion = try c.decodeIfPresent(Int.self, forKey: .dropdownSchemaVersion) ?? 1
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'dropdownSchemaVersion': \(error)")
            #endif
            throw error
        }
        
        do {
            self.lastModifiedBy = try c.decodeIfPresent(String.self, forKey: .lastModifiedBy)
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'lastModifiedBy': \(error)")
            #endif
            throw error
        }
        
        // Back‑compat: default to empty if missing
        do {
            self.statusHistory = try c.decodeIfPresent([WO_Status].self, forKey: .statusHistory) ?? []
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'statusHistory': \(error)")
            #endif
            throw error
        }
        
        // Back‑compat: default to an empty notes array if missing
        do {
            self.notes = try c.decodeIfPresent([WO_Note].self, forKey: .notes) ?? []
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'notes': \(error)")
            #endif
            throw error
        }

        // Additional fields with defaults
        do {
            self.testResult = try c.decodeIfPresent(String.self, forKey: .testResult)
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'testResult': \(error)")
            #endif
            throw error
        }
        
        do {
            self.partsUsed = try c.decodeIfPresent(String.self, forKey: .partsUsed)
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'partsUsed': \(error)")
            #endif
            throw error
        }
        
        do {
            self.hoursWorked = try c.decodeIfPresent(String.self, forKey: .hoursWorked)
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'hoursWorked': \(error)")
            #endif
            throw error
        }
        
        do {
            self.cost = try c.decodeIfPresent(String.self, forKey: .cost)
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'cost': \(error)")
            #endif
            throw error
        }
        
        do {
            self.assignedTo = try c.decodeIfPresent(String.self, forKey: .assignedTo) ?? ""
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'assignedTo': \(error)")
            #endif
            throw error
        }
        
        do {
            self.isFlagged = try c.decodeIfPresent(Bool.self, forKey: .isFlagged) ?? false
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'isFlagged': \(error)")
            #endif
            throw error
        }
        
        do {
            self.tagReplacementHistory = try c.decodeIfPresent([TagReplacement].self, forKey: .tagReplacementHistory)
        } catch {
            #if DEBUG
            print("❌ WO_Item decode failed on 'tagReplacementHistory': \(error)")
            #endif
            throw error
        }

        // 🔒 Local-only: never decoded/encoded
        self.localImages = []
        
        #if DEBUG
        print("✅ WO_Item decode successful: \(self.id) (\(self.type))")
        #endif
    }
    
    // ───── Explicit Encoder ─────
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        
        #if DEBUG
        print("🔧 WO_Item encoding: \(type) (id: \(id))")
        #endif
        
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(woItemId, forKey: .woItemId)
        try c.encodeIfPresent(tagId, forKey: .tagId)
        try c.encode(type, forKey: .type)
        try c.encode(dropdowns, forKey: .dropdowns)
        try c.encode(reasonsForService, forKey: .reasonsForService)
        try c.encodeIfPresent(reasonNotes, forKey: .reasonNotes)
        try c.encode(completedReasons, forKey: .completedReasons)
        try c.encode(imageUrls, forKey: .imageUrls)
        try c.encode(thumbUrls, forKey: .thumbUrls)
        try c.encode(lastModified, forKey: .lastModified)
        try c.encode(dropdownSchemaVersion, forKey: .dropdownSchemaVersion)
        try c.encodeIfPresent(lastModifiedBy, forKey: .lastModifiedBy)
        try c.encode(statusHistory, forKey: .statusHistory)
        try c.encode(notes, forKey: .notes)
        try c.encodeIfPresent(testResult, forKey: .testResult)
        try c.encodeIfPresent(partsUsed, forKey: .partsUsed)
        try c.encodeIfPresent(hoursWorked, forKey: .hoursWorked)
        try c.encodeIfPresent(cost, forKey: .cost)
        try c.encode(assignedTo, forKey: .assignedTo)
        try c.encode(isFlagged, forKey: .isFlagged)
        try c.encodeIfPresent(tagReplacementHistory, forKey: .tagReplacementHistory)
        
        #if DEBUG
        print("✅ WO_Item encoding successful: \(type)")
        #endif
    }
}
// ───── Explicit Init for Preview / Tests ─────
extension WO_Item {
    init(
        id: UUID,
        woItemId: String?,
        tagId: String?,
        imageUrls: [String],
        thumbUrls: [String],
        type: String,
        dropdowns: [String: String],
        dropdownSchemaVersion: Int,
        reasonsForService: [String],
        reasonNotes: String?,
        completedReasons: [String],
        statusHistory: [WO_Status],
        testResult: String?,
        partsUsed: String?,
        hoursWorked: String?,
        cost: String?,
        assignedTo: String,
        isFlagged: Bool,
        tagReplacementHistory: [TagReplacement]?
    ) {
        self.id = id
        self.woItemId = woItemId
        self.tagId = tagId
        self.imageUrls = imageUrls
        self.thumbUrls = thumbUrls
        self.type = type
        self.dropdowns = dropdowns
        self.dropdownSchemaVersion = dropdownSchemaVersion
        self.reasonsForService = reasonsForService
        self.reasonNotes = reasonNotes
        self.completedReasons = completedReasons
        self.statusHistory = statusHistory
        self.testResult = testResult
        self.partsUsed = partsUsed
        self.hoursWorked = hoursWorked
        self.cost = cost
        self.localImages = [] // local-only
        self.lastModified = Date()
        self.lastModifiedBy = "Preview"
        self.isFlagged = isFlagged
        self.notes = []
    }
}


// ───── Preview Stub ─────
extension WO_Item {
    static let sample = WO_Item(
        id: UUID(),
        woItemId: "250826-001-WOI-001",
        tagId: "TEST123",
        imageUrls: [],
        thumbUrls: [],
        type: "Cylinder",
        dropdowns: [
            "size": "3\" Bore",
            "color": "Yellow",
            "colorHex": "#FFD700",
            "machineType": "Forklift",
            "machineBrand": "Bobcat",
            "waitTime": "1–2 Days"
        ],
        dropdownSchemaVersion: 1,
        reasonsForService: ["Leaking", "Other"],
        reasonNotes: "This is just a sample note.",
        completedReasons: [],
        statusHistory: [],
        testResult: nil,
        partsUsed: nil,
        hoursWorked: nil,
        cost: nil,
        assignedTo: "Preview",
        isFlagged: false,
        tagReplacementHistory: nil
    )
}
extension WO_Item {
    static func blank() -> WO_Item {
        WO_Item.create()
    }
    
    // MARK: - WO Item ID Generation
    static func generateWOItemId(woNumber: String, itemIndex: Int) -> String {
        let formattedIndex = String(format: "%03d", itemIndex + 1)  // 001, 002, 003, etc.
        return "\(woNumber)-WOI-\(formattedIndex)"
    }
    
    // MARK: - WO Item ID Validation
    static func isValidWOItemId(_ woItemId: String) -> Bool {
        // Format: {WO_Number}-WOI-{ItemNumber}
        // Example: 250826-653-WOI-001
        let pattern = #"^\d{6}-\d{3}-WOI-\d{3}$"#
        return woItemId.range(of: pattern, options: .regularExpression) != nil
    }
    
    // MARK: - WO Item ID Parsing
    static func parseWOItemId(_ woItemId: String) -> (woNumber: String, itemNumber: Int)? {
        let components = woItemId.components(separatedBy: "-")
        guard components.count == 4,
              components[2] == "WOI",
              let itemNumber = Int(components[3]) else {
            return nil
        }
        let woNumber = "\(components[0])-\(components[1])"
        return (woNumber, itemNumber)
    }
}
