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
    public var pin: String?              // 4-8 digit PIN for login (optional, defaults to role-based)
    public var createdAt: Date
    public var updatedAt: Date
    public var createdByUserId: String?
    public var updatedByUserId: String?
    
    // MARK: - Initializers
    public init(
        id: String,
        displayName: String,
        phoneE164: String?,
        role: UserRole,
        isActive: Bool,
        pin: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        createdByUserId: String?,
        updatedByUserId: String?
    ) {
        self.id = id
        self.displayName = displayName
        self.phoneE164 = phoneE164
        self.role = role
        self.isActive = isActive
        self.pin = pin
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdByUserId = createdByUserId
        self.updatedByUserId = updatedByUserId
    }
}
// END