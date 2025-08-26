import Foundation
import SwiftUI

struct WO_Item: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var tagId: String? = nil
    var type: String = ""

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
        case id, tagId, type, dropdowns, reasonsForService, reasonNotes, completedReasons,
             imageUrls, thumbUrls, lastModified, dropdownSchemaVersion, lastModifiedBy,
             statusHistory, notes
    }

}

// ───── Back-compat Codable init (defaults missing keys) ─────
extension WO_Item {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
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
        tagId: "TEST123",
        type: "Cylinder",
        dropdowns: [
            "size": "3\" Bore",
            "color": "Yellow",
            "colorHex": "#FFD700",
            "machineType": "Forklift",
            "machineBrand": "Bobcat",
            "waitTime": "1–2 Days"
        ],
        reasonsForService: ["Leaking", "Other"],
        reasonNotes: "This is just a sample note.",
        completedReasons: [],
        imageUrls: []
    )
}
extension WO_Item {
    static func blank() -> WO_Item {
        WO_Item()
    }
}
