//
//  UserRole.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 UserRole.swift
// User roles for PIN-based login and role-based routing
// ─────────────────────────────────────────────────────────────

import Foundation

enum UserRole: String, Codable {
    case tech
    case manager
    case admin
    case superadmin
}
