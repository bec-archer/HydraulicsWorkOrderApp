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
    
    var id: UUID = UUID()       // Local-only — not used as Firestore doc ID
    var user: String            // Who wrote the note
    var text: String            // Content of the note
    var timestamp: Date         // When it was added

    // END
}

// MARK: - Sample

extension WO_Note {
    static let sample = WO_Note(
        user: "Maria",
        text: "Customer says this one leaks worse under pressure.",
        timestamp: Date()
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
