//
//  WorkOrdersDatabase.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 WorkOrdersDatabase.swift
// Handles Firestore read/write logic for WorkOrders
// ─────────────────────────────────────────────────────────────

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - WorkOrdersDatabase

final class WorkOrdersDatabase: ObservableObject {
    static let shared = WorkOrdersDatabase()

    private let collectionName = "workOrders"
    private let db = Firestore.firestore()

    @Published var workOrders: [WorkOrder] = []

    private init() {}

    // ───── ADD NEW WORK ORDER TO FIRESTORE ─────
    func addWorkOrder(_ workOrder: WorkOrder, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let _ = try db.collection(collectionName).addDocument(from: workOrder) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    DispatchQueue.main.async {
                        self.workOrders.append(workOrder)
                    }
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // ───── FETCH ALL WORK ORDERS FROM FIRESTORE (lenient decode) ─────
    func fetchAllWorkOrders(completion: @escaping (Result<[WorkOrder], Error>) -> Void) {
        db.collection(collectionName)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { self.workOrders = [] }
                    completion(.success([]))
                    return
                }

                var decoded: [WorkOrder] = []
                var failures: [(id: String, message: String)] = []

                for doc in docs {
                    do {
                        let wo = try doc.data(as: WorkOrder.self)
                        decoded.append(wo)
                    } catch let DecodingError.keyNotFound(key, context) {
                        let msg = "Missing key '\(key.stringValue)' in \(doc.documentID) – \(context.debugDescription)"
                        print("⚠️ WorkOrder decode skipped:", msg)
                        failures.append((doc.documentID, msg))
                    } catch let DecodingError.valueNotFound(type, context) {
                        let msg = "Value of type \(type) not found in \(doc.documentID) – \(context.debugDescription)"
                        print("⚠️ WorkOrder decode skipped:", msg)
                        failures.append((doc.documentID, msg))
                    } catch {
                        let msg = "Unknown decode error in \(doc.documentID): \(error.localizedDescription)"
                        print("⚠️ WorkOrder decode skipped:", msg)
                        failures.append((doc.documentID, msg))
                    }
                }

                DispatchQueue.main.async { self.workOrders = decoded }

                // If at least one decoded, treat as success and show what we have.
                if !decoded.isEmpty {
                    completion(.success(decoded))
                } else if failures.isEmpty {
                    completion(.success([])) // nothing in collection
                } else {
                    // Surface a concise error so the UI can show an alert (dev-friendly)
                    let combined = failures.map { "\($0.id): \($0.message)" }.joined(separator: " • ")
                    completion(.failure(NSError(domain: "WorkOrdersDatabase",
                                                code: -1,
                                                userInfo: [NSLocalizedDescriptionKey: "No decodable WorkOrders. \(combined)"])))
                }
            }
    }
    // END


    // END
}
