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
             statusHistory, notes
    }

}

// ───── Back-compat Codable init (defaults missing keys) ─────
extension WO_Item {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.woItemId = try c.decodeIfPresent(String.self, forKey: .woItemId)
        self.tagId = try c.decodeIfPresent(String.self, forKey: .tagId)
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""

        self.dropdowns = try c.decodeIfPresent([String:String].self, forKey: .dropdowns) ?? [:]
        self.reasonsForService = try c.decodeIfPresent([String].self, forKey: .reasonsForService) ?? []
        self.reasonNotes = try c.decodeIfPresent(String.self, forKey: .reasonNotes)
        self.completedReasons = try c.decodeIfPresent([String].self, forKey: .completedReasons) ?? []

        // 🔑 Back-compat: default to [] when key missing
        self.imageUrls = try c.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        self.thumbUrls = try c.decodeIfPresent([String].self, forKey: .thumbUrls) ?? []

        self.lastModified = try c.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        self.dropdownSchemaVersion = try c.decodeIfPresent(Int.self, forKey: .dropdownSchemaVersion) ?? 1
        self.lastModifiedBy = try c.decodeIfPresent(String.self, forKey: .lastModifiedBy)
        // Back‑compat: default to empty if missing
        self.statusHistory = try c.decodeIfPresent([WO_Status].self, forKey: .statusHistory) ?? []
        // Back‑compat: default to an empty notes array if missing
        self.notes = try c.decodeIfPresent([WO_Note].self, forKey: .notes) ?? []


        // 🔒 Local-only: never decoded/encoded
        self.localImages = []
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
