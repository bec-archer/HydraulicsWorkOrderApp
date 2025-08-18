//
//  WO_Note.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 WO_Note.swift
// Freeform notes attached to a WorkOrder
// ─────────────────────────────────────────────────────────────
import SwiftUI
import Foundation
import FirebaseFirestoreSwift

// MARK: - WO_Note Model

struct WO_Note: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var user: String
    var text: String
    var timestamp: Date
    var imageURLs: [String]

    // ───── Custom Decoder to Handle Missing 'imageURLs' ─────
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id         = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        user       = try container.decode(String.self, forKey: .user)
        text       = try container.decode(String.self, forKey: .text)
        timestamp  = try container.decode(Date.self, forKey: .timestamp)
        imageURLs  = try container.decodeIfPresent([String].self, forKey: .imageURLs) ?? []
    }

    // Leave default initializer
    init(id: UUID = UUID(), user: String, text: String, timestamp: Date, imageURLs: [String] = []) {
        self.id = id
        self.user = user
        self.text = text
        self.timestamp = timestamp
        self.imageURLs = imageURLs
    }
}


// MARK: - Sample

extension WO_Note {
    static let sample = WO_Note(
        user: "Maria",
        text: "Customer says this one leaks worse under pressure.",
        timestamp: Date(),
        imageURLs: []
    )
}

// ───── Preview Template ─────

#Preview {
    VStack(alignment: .leading) {
        Text("WO_Note Preview")
            .font(.title2)
        Text(WO_Note.sample.text)
            .padding(.top)
        Text("By: \(WO_Note.sample.user)")
            .font(.footnote)
    }
    .padding()
   // .previewLayout(.sizeThatFits)
}
