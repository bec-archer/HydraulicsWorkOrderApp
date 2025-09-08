//
//  TagReplacement.swift
//  HydraulicsWorkOrderApp
//
//  Tracks when an RFID/QR tag was replaced on a WO_Item
//
import Foundation

// MARK: - TagReplacement Model

struct TagReplacement: Identifiable, Codable, Equatable {
    var id: UUID = UUID()         // Unique identifier
    var oldTagId: String          // Previous tag ID
    var newTagId: String          // New tag ID
    var replacedBy: String        // Who performed the replacement
    var timestamp: Date           // When it was replaced
    var reason: String?           // Optional description of why

    // MARK: - Initializers
    init(
        id: UUID = UUID(),
        oldTagId: String,
        newTagId: String,
        replacedBy: String,
        timestamp: Date = Date(),
        reason: String? = nil
    ) {
        self.id = id
        self.oldTagId = oldTagId
        self.newTagId = newTagId
        self.replacedBy = replacedBy
        self.timestamp = timestamp
        self.reason = reason
    }
    
    // MARK: - Convenience Initializer
    init() {
        self.id = UUID()
        self.oldTagId = ""
        self.newTagId = ""
        self.replacedBy = ""
        self.timestamp = Date()
        self.reason = nil
    }
}

// MARK: - Extensions
extension TagReplacement {
    
    // MARK: - Validation
    var isValid: Bool {
        !oldTagId.isEmpty && !newTagId.isEmpty && !replacedBy.isEmpty
    }
    
    // MARK: - Computed Properties
    var displayText: String {
        if let reason = reason, !reason.isEmpty {
            return "\(oldTagId) → \(newTagId) (\(reason))"
        }
        return "\(oldTagId) → \(newTagId)"
    }
    
    var isRecent: Bool {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return timestamp > oneWeekAgo
    }
}

// MARK: - Sample
extension TagReplacement {
    static let sample = TagReplacement(
        oldTagId: "QR-ABC123",
        newTagId: "QR-XYZ789",
        replacedBy: "Maria",
        reason: "Tag damaged"
    )
}
