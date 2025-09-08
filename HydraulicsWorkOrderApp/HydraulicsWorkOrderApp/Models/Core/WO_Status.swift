//
//  WO_Status.swift
//  HydraulicsWorkOrderApp
//
//  Represents a status update in a WO_Item timeline
//
import Foundation

// MARK: - WO_Status Model

struct WO_Status: Identifiable, Codable, Equatable {
    var id: UUID = UUID()         // Unique identifier
    var status: String            // e.g., "In Progress", "Completed"
    var user: String              // Who changed it
    var timestamp: Date           // When it was updated
    var notes: String?            // Optional notes

    // MARK: - Initializers
    init(
        id: UUID = UUID(),
        status: String,
        user: String,
        timestamp: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.status = status
        self.user = user
        self.timestamp = timestamp
        self.notes = notes
    }
    
    // MARK: - Convenience Initializer
    init() {
        self.id = UUID()
        self.status = ""
        self.user = ""
        self.timestamp = Date()
        self.notes = nil
    }
}

// MARK: - Extensions
extension WO_Status {
    
    // MARK: - Validation
    var isValid: Bool {
        !status.isEmpty && !user.isEmpty
    }
    
    // MARK: - Computed Properties
    var displayText: String {
        if let notes = notes, !notes.isEmpty {
            return "\(status) - \(notes)"
        }
        return status
    }
    
    var isCompleted: Bool {
        status.lowercased().contains("complete") || status.lowercased().contains("done")
    }
    
    var isInProgress: Bool {
        status.lowercased().contains("progress") || status.lowercased().contains("working")
    }
}
