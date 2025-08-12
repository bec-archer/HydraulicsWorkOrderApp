import Foundation
import SwiftUI

struct WO_Item: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var tagId: String? = nil
    var type: String = ""

    var dropdowns: [String: String] = [:]
    var reasonsForService: [String] = []
    var reasonNotes: String? = nil

    var imageUrls: [String] = []
    var thumbUrls: [String] = []       // 🆕 store thumbnails for fast UI
    var localImages: [UIImage] = []    // ✅ No longer using @TransientImageStorage
    // 🆕 Store local images for offline use
    var lastModified: Date = Date()
    var dropdownSchemaVersion: Int = 1
    var lastModifiedBy: String? = nil
}

// Ignore localImages in Codable
extension WO_Item {
    enum CodingKeys: String, CodingKey {
        case id, tagId, type, dropdowns, reasonsForService, reasonNotes,
             imageUrls, thumbUrls, lastModified, dropdownSchemaVersion, lastModifiedBy
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

        // 🔑 Back-compat: default to [] when key missing
        self.imageUrls = try c.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        self.thumbUrls = try c.decodeIfPresent([String].self, forKey: .thumbUrls) ?? []

        self.lastModified = try c.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        self.dropdownSchemaVersion = try c.decodeIfPresent(Int.self, forKey: .dropdownSchemaVersion) ?? 1
        self.lastModifiedBy = try c.decodeIfPresent(String.self, forKey: .lastModifiedBy)

        // 🔒 Local-only: never decoded/encoded
        self.localImages = []
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
        imageUrls: []
    )
}
extension WO_Item {
    static func blank() -> WO_Item {
        WO_Item()
    }
}
