//
//  WO_Note.swift
//  HydraulicsWorkOrderApp
//
//  Freeform notes attached to a WorkOrder or WO_Item
//
import SwiftUI
import Foundation

// MARK: - WO_Note Model

struct WO_Note: Identifiable, Codable, Equatable, Hashable {
    
    var id: UUID = UUID()           // Local-only — not used as Firestore doc ID
    var workOrderId: String         // Reference to parent WorkOrder
    var itemId: String?             // Optional reference to parent WO_Item
    var user: String                // Who wrote the note
    var text: String                // Content of the note
    var timestamp: Date             // When it was added
    var imageUrls: [String] = []    // Optional image URLs attached to note

    // MARK: - Initializers
    init(
        id: UUID = UUID(),
        workOrderId: String,
        itemId: String? = nil,
        user: String,
        text: String,
        timestamp: Date = Date(),
        imageUrls: [String] = []
    ) {
        self.id = id
        self.workOrderId = workOrderId
        self.itemId = itemId
        self.user = user
        self.text = text
        self.timestamp = timestamp
        self.imageUrls = imageUrls
    }
    
    // MARK: - Convenience Initializer
    init() {
        self.id = UUID()
        self.workOrderId = ""
        self.itemId = nil
        self.user = ""
        self.text = ""
        self.timestamp = Date()
        self.imageUrls = []
    }

    // MARK: - Sample
    static let sample = WO_Note(
        workOrderId: "sample-wo-id",
        user: "John Doe",
        text: "This is a sample note for preview purposes."
    )
}

// MARK: - Extensions
extension WO_Note {
    
    // MARK: - Validation
    var isValid: Bool {
        !workOrderId.isEmpty && !user.isEmpty && !text.isEmpty
    }
    
    // MARK: - Computed Properties
    var isItemNote: Bool {
        itemId != nil
    }
    
    var isWorkOrderNote: Bool {
        itemId == nil
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
