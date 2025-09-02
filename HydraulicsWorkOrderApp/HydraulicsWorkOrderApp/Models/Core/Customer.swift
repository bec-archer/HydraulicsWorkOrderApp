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
    var customerTag: String? = nil       // Used for subtle internal labels (e.g., 🌟 / 🐢 / 🧨)
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
        taxExempt: false,
        customerTag: "🌟"
    )

}

import SwiftUI

struct Customer_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            if let tag = Customer.sample.customerTag {
                Text("\(Customer.sample.name) \(tag)")
            } else {
                Text(Customer.sample.name)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
