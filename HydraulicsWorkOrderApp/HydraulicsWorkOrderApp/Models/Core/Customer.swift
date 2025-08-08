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

struct Customer: Identifiable, Codable, Equatable {
    @DocumentID var id: String?             // Firebase doc ID

    var name: String                        // Customer name
    var phone: String                       // Primary contact (used for lookup)
    var company: String?                    // Optional company name
    var email: String?                      // Optional contact email
    var taxExempt: Bool                     // Optional toggle

    // END
}

// MARK: - Sample

extension Customer {
    static let sample = Customer(
        id: "sample-id",
        name: "Maria Rivera",
        phone: "555-1234",
        company: "Suncoast Hydraulics",
        email: "maria@example.com",
        taxExempt: false
    )
}
