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
    var localImages: [UIImage] = []    // ✅ No longer using @TransientImageStorage

    var lastModified: Date = Date()
    var dropdownSchemaVersion: Int = 1
    var lastModifiedBy: String? = nil
}

// Ignore localImages in Codable
extension WO_Item {
    enum CodingKeys: String, CodingKey {
        case id, tagId, type, dropdowns, reasonsForService, reasonNotes,
             imageUrls, lastModified, dropdownSchemaVersion, lastModifiedBy
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
