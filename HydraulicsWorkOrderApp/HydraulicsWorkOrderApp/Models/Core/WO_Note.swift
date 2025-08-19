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
import FirebaseFirestore

// MARK: - WO_Note Model

struct WO_Note: Identifiable, Codable, Equatable {
    
    var id: UUID = UUID()       // Local-only — not used as Firestore doc ID
    var user: String            // Who wrote the note
    var text: String            // Content of the note
    var timestamp: Date         // When it was added
    var imageURLs: [String] = []  // Optional image URLs attached to note

    // MARK: - Sample
    static let sample = WO_Note(
        user: "John Doe",
        text: "This is a sample note for preview purposes.",
        timestamp: Date()
    )
}

// MARK: - Firebase Extension
extension WO_Note {
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "user": user,
            "text": text,
            "timestamp": Timestamp(date: timestamp),
            "imageURLs": imageURLs
        ]
    }
}

// MARK: - Preview

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
}
