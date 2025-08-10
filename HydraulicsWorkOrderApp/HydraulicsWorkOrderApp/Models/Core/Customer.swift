//
//  Customer.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 Customer.swift
// Represents a customer record (lookup, creation, display)
// ─────────────────────────────────────────────────────────────

import Foundation
import FirebaseFirestoreSwift

// ─────────────────────────────────────────────────────────────
// 📄 Customer.swift
// Canonical Customer model — UUID id in-app, Firestore stores as String
// ─────────────────────────────────────────────────────────────

import Foundation

struct Customer: Identifiable, Codable, Equatable {
    let id: UUID                         // ✅ Non-optional UUID
    var name: String
    var phone: String
    var company: String?
    var email: String?
    var taxExempt: Bool
}
// END Customer


// MARK: - Sample

extension Customer {
    static let sample = Customer(
        id: UUID(), // ✅ generates a valid UUID for sample data
        name: "Maria Rivera",
        phone: "555-1234",
        company: "Suncoast Hydraulics",
        email: "maria@example.com",
        taxExempt: false
    )

}
