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

    // ───── SEARCH BY NAME OR PHONE ─────
    func searchCustomers(matching query: String) -> [Customer] {
        let lowerQuery = query.lowercased()
        return customers.filter {
            $0.name.lowercased().contains(lowerQuery) ||
            $0.phone.contains(lowerQuery)
        }
    }

    // ───── FETCH ALL CUSTOMERS ─────
    func fetchCustomers() {
        db.collection(collection)
            .order(by: "name")
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    do {
                        let decoded = try documents.compactMap {
                            try $0.data(as: Customer.self)
                        }
                        DispatchQueue.main.async {
                            self.customers = decoded
                        }
                    } catch {
                        print("❌ Failed to decode customers: \(error)")
                    }
                }
            }
    }

    // ───── ADD NEW CUSTOMER ─────
    func addCustomer(_ customer: Customer, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let _ = try db.collection(collection).addDocument(from: customer) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    self.fetchCustomers()
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // END
}
