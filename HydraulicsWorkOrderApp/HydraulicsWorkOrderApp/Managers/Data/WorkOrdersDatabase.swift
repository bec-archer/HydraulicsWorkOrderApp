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

    // ───── FETCH ALL WORK ORDERS FROM FIRESTORE ─────
    func fetchAllWorkOrders(completion: @escaping (Result<[WorkOrder], Error>) -> Void) {
        db.collection(collectionName)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    do {
                        let workOrders = try snapshot?.documents.compactMap {
                            try $0.data(as: WorkOrder.self)
                        } ?? []
                        DispatchQueue.main.async {
                            self.workOrders = workOrders
                        }
                        completion(.success(workOrders))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
    }

    // END
}
