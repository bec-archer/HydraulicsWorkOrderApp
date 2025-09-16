//
//  QRNumberTracker.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 1/15/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// ───── MODEL ───────────────────────────────────────────────────────────────────

struct QRNumberTracker: Codable {
    var id: String = "HYDSR80" // Document ID matches prefix
    var prefix: String = "HYDSR80"
    var lastGeneratedNumber: Int = 0
    var lastUpdated: Date = Date()
    var lastUpdatedBy: String = ""
    var lastUpdatedByName: String = ""
}

// ───── MANAGER ────────────────────────────────────────────────────────────────

final class QRNumberTrackerManager: ObservableObject {
    
    static let shared = QRNumberTrackerManager()
    private let db = Firestore.firestore()
    private let collectionName = "qrNumberTracker"
    
    private init() {}
    
    // ───── GET NEXT AVAILABLE NUMBER ─────
    
    /// Gets the next available number for the HYDSR80 prefix
    /// This will increment from the last generated number
    func getNextAvailableNumber(for user: User) async throws -> Int {
        let tracker = try await getOrCreateTracker(for: user)
        let nextNumber = tracker.lastGeneratedNumber + 1
        
        // Update the tracker with the new number
        try await updateLastGeneratedNumber(nextNumber, for: user)
        
        return nextNumber
    }
    
    // ───── GET CURRENT TRACKER ─────
    
    /// Gets the current tracker or creates one if it doesn't exist
    private func getOrCreateTracker(for user: User) async throws -> QRNumberTracker {
        let docRef = db.collection(collectionName).document("HYDSR80")
        
        do {
            let document = try await docRef.getDocument()
            if document.exists {
                return try document.data(as: QRNumberTracker.self)
            } else {
                // Create new tracker starting at 0
                let newTracker = QRNumberTracker(
                    lastUpdatedBy: user.id,
                    lastUpdatedByName: user.displayName
                )
                try docRef.setData(from: newTracker)
                return newTracker
            }
        } catch {
            throw error
        }
    }
    
    // ───── UPDATE TRACKER ─────
    
    /// Updates the last generated number in Firebase
    private func updateLastGeneratedNumber(_ number: Int, for user: User) async throws {
        let docRef = db.collection(collectionName).document("HYDSR80")
        
        let updateData: [String: Any] = [
            "lastGeneratedNumber": number,
            "lastUpdated": Timestamp(date: Date()),
            "lastUpdatedBy": user.id,
            "lastUpdatedByName": user.displayName
        ]
        
        try await docRef.updateData(updateData)
    }
    
    // ───── GET CURRENT STATUS ─────
    
    /// Gets the current tracker status without incrementing
    func getCurrentStatus() async throws -> QRNumberTracker {
        let systemUser = User(
            id: "system",
            displayName: "System",
            phoneE164: nil,
            role: .admin,
            isActive: true,
            pin: nil,
            createdAt: Date(),
            updatedAt: Date(),
            createdByUserId: nil,
            updatedByUserId: nil
        )
        return try await getOrCreateTracker(for: systemUser)
    }
    
    // ───── MANUAL RESET (ADMIN ONLY) ─────
    
    /// Manually resets the counter to a specific number (Admin/SuperAdmin only)
    func resetCounter(to number: Int, for user: User) async throws {
        let docRef = db.collection(collectionName).document("HYDSR80")
        
        let resetData: [String: Any] = [
            "lastGeneratedNumber": number,
            "lastUpdated": Timestamp(date: Date()),
            "lastUpdatedBy": user.id,
            "lastUpdatedByName": user.displayName
        ]
        
        try await docRef.setData(resetData, merge: true)
    }
}
