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

// ───── USER ROLE ENUM ─────
import Foundation

public enum UserRole: String, CaseIterable, Codable, Equatable {
    case tech
    case manager
    case admin
    case superadmin   // NOTE: keeps AppState.isSuperAdmin gate working
}
// END
