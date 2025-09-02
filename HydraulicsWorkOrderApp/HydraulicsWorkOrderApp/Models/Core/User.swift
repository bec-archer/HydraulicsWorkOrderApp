//
//  User.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//


// ───── USER MODEL ─────
import Foundation

public struct User: Identifiable, Codable, Equatable {
    public let id: String                // Firestore doc id (UUID string ok)
    public var displayName: String       // 2–80 chars
    public var phoneE164: String?        // +15551234567 (optional for now)
    public var role: UserRole            // tech/manager/admin/superadmin
    public var isActive: Bool            // soft deactivate
    public var createdAt: Date
    public var updatedAt: Date
    public var createdByUserId: String?
    public var updatedByUserId: String?
}
// END