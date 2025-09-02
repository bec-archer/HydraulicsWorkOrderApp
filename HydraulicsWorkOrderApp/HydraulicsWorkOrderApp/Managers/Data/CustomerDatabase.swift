//
//  CustomerDatabase.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 CustomerDatabase.swift
// Firebase-backed lookup and save logic for customers
// ─────────────────────────────────────────────────────────────

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class CustomerDatabase: ObservableObject {
    static let shared = CustomerDatabase()
    private let db = Firestore.firestore()
    private let collection = "customers"

    @Published var customers: [Customer] = []

    private init() {}

    // ───── SEARCH BY NAME, PHONE, OR COMPANY ─────
    func searchCustomers(matching query: String) -> [Customer] {
        let lowerQuery = query.lowercased()
        return customers.filter {
            $0.name.lowercased().contains(lowerQuery) ||
            $0.phone.contains(lowerQuery) ||
            ($0.company?.lowercased().contains(lowerQuery) ?? false)
        }
    }

    // ───── FETCH ALL CUSTOMERS ─────
    func fetchCustomers() {
        db.collection(collection)
            .order(by: "name")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { return }

                // Try Codable first; if 'id' is missing or wrong type, map manually.
                let mapped: [Customer] = documents.compactMap { doc in
                    // 1) Best case: full Codable decode works (e.g., when 'id' was stored in the doc)
                    if let c = try? doc.data(as: Customer.self) {
                        return c
                    }

                    // 2) Manual map: pull fields; build a Customer using docID (UUID string) or 'id' field
                    let data = doc.data()

                    guard
                        let name = data["name"] as? String,
                        let phone = data["phone"] as? String
                    else {
                        print("⚠️ Skipping customer \(doc.documentID): missing required fields")
                        return nil
                    }

                    let company = data["company"] as? String
                    let email = data["email"] as? String
                    let taxExempt = data["taxExempt"] as? Bool ?? false
                    let customerTag = data["customerTag"] as? String

                    // Prefer documentID if it is a UUID string; else try "id" field; else generate UUID
                    let docUUID = UUID(uuidString: doc.documentID)
                    let fieldUUID = (data["id"] as? String).flatMap(UUID.init(uuidString:))
                    let uuid = docUUID ?? fieldUUID ?? UUID()

                    return Customer(
                        id: uuid,
                        name: name,
                        phone: phone,
                        company: company,
                        email: email,
                        taxExempt: taxExempt,
                        customerTag: customerTag
                    )
                }

                DispatchQueue.main.async {
                    self.customers = mapped
                }
            }
    }


    // ───── ADD NEW CUSTOMER ─────
    // Store using the Customer.id (UUID) as the Firestore document ID (String)
    func addCustomer(_ customer: Customer, completion: @escaping (Result<Void, Error>) -> Void) {
        let docId = customer.id.uuidString // ✅ deterministic, derived from UUID

        do {
            try db.collection(collection)
                .document(docId)
                .setData(from: customer) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        // Ensure the doc contains its own id field (string) for easy querying
                        self.db.collection(self.collection)
                            .document(docId)
                            .setData(["id": docId], merge: true)

                        self.fetchCustomers() // refresh local cache so live search sees it
                        completion(.success(()))
                    }
                }
        } catch {
            completion(.failure(error))
        }
    }

    // ───── UPDATE EXISTING CUSTOMER ─────
    func updateCustomer(_ customer: Customer, completion: @escaping (Result<Void, Error>) -> Void) {
        let docId = customer.id.uuidString
        
        do {
            try db.collection(collection)
                .document(docId)
                .setData(from: customer) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        // Ensure the doc contains its own id field (string) for easy querying
                        self.db.collection(self.collection)
                            .document(docId)
                            .setData(["id": docId], merge: true)
                        
                        self.fetchCustomers() // refresh local cache
                        completion(.success(()))
                    }
                }
        } catch {
            completion(.failure(error))
        }
    }

}
