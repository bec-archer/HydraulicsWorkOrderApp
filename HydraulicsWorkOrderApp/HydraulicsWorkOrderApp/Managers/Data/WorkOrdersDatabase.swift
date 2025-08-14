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
    // ───── Generate Next WO Number (YYmmdd-###) ─────
    /// Looks up all WorkOrders whose WO_Number starts with today's prefix (UTC),
    /// finds the highest sequence used, and returns the next one in format YYmmdd-###.
    ///
    /// Notes:
    /// - Uses string range query: [prefix, prefix + "~") because "~" sorts after digits.
    /// - We compute max sequence (not just count) so gaps won't cause duplicates.
    /// - If you want to ignore deleted WOs, add: .whereField("isDeleted", isEqualTo: false)
    // ───── Generate Next WO Number (YYmmdd-###) ─────
    func generateNextWONumber(completion: @escaping (Result<String, Error>) -> Void) {
        let prefix = WorkOrderNumberGenerator.dailyPrefix() // e.g., "250814"

        // Range on WO_Number for today's docs, then order by WO_Number desc and take 1
        let lower = prefix
        let upper = "\(prefix)~" // tilde sorts after digits

        db.collection(collectionName)
            .whereField("WO_Number", isGreaterThanOrEqualTo: lower)
            .whereField("WO_Number", isLessThan: upper)
            .order(by: "WO_Number", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in

                if let error = error {
                    print("❌ generateNextWONumber query failed: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                // Extract highest existing suffix (if any)
                let latest = snapshot?.documents.first?["WO_Number"] as? String
                let nextSeq: Int = {
                    guard let s = latest else { return 1 }
                    let parts = s.split(separator: "-")
                    guard parts.count == 2, parts[0] == Substring(prefix), let n = Int(parts[1]) else { return 1 }
                    return n + 1
                }()

                let number = WorkOrderNumberGenerator.build(prefix: prefix, sequence: nextSeq)
                completion(.success(number))
            }
    }
    // END Generate Next WO Number


    // ───── ADD NEW WORK ORDER TO FIRESTORE ─────
    func addWorkOrder(_ workOrder: WorkOrder, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            // Declare outside so the closure can read it without capture-order issues
            var docRef: DocumentReference?

            docRef = try db.collection(collectionName).addDocument(from: workOrder) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Success: update local cache with the Firestore documentID
                DispatchQueue.main.async {
                    var woWithId = workOrder
                    woWithId.id = docRef?.documentID            // @DocumentID var id: String?
                    self.workOrders.append(woWithId)
                }
                completion(.success(()))
            }

            _ = docRef // keep reference alive until closure runs
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
                        var wo = try doc.data(as: WorkOrder.self)
                        if wo.id == nil { wo.id = doc.documentID } // backfill if custom decoder didn’t set it
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

    // ───── SOFT DELETE WORK ORDER (role‑gated by caller) ─────
    /// Marks a WorkOrder as deleted in Firestore and updates local cache.
    /// Looks up the document by **Firestore documentID** stored in `workOrder.id` (@DocumentID).
    func softDelete(_ workOrder: WorkOrder,
                    by user: String? = nil,
                    completion: @escaping (Result<Void, Error>) -> Void) {

        let userName = (user?.isEmpty == false) ? user! : "system"

        // We must have the Firestore documentID here (set by @DocumentID when decoding).
        guard let idString = workOrder.id, !idString.isEmpty else {
            completion(.failure(NSError(domain: "WorkOrdersDatabase",
                                        code: 400,
                                        userInfo: [NSLocalizedDescriptionKey: "WorkOrder has no Firestore documentID."])))
            return
        }

        // Prepare updates for the soft delete
        let updates: [String: Any] = [
            "isDeleted": true,
            "lastModified": Date(),
            "lastModifiedBy": userName
        ]

        let docRef = db.collection(collectionName).document(idString)

        // Optional: check existence first for nicer 404 message
        docRef.getDocument { [weak self] snapshot, err in
            guard let self else { return }

            if let err = err {
                completion(.failure(err))
                return
            }
            guard let snapshot, snapshot.exists else {
                completion(.failure(NSError(domain: "WorkOrdersDatabase",
                                            code: 404,
                                            userInfo: [NSLocalizedDescriptionKey: "WorkOrder document not found for id \(idString)"])))
                return
            }

            // ───── Apply soft delete ─────
            docRef.updateData(updates) { err in
                if let err = err {
                    completion(.failure(err))
                    return
                }

                // Update local cache so UI reflects the delete immediately
                DispatchQueue.main.async {
                    if let idx = self.workOrders.firstIndex(where: { $0.id == workOrder.id }) {
                        var updated = self.workOrders[idx]
                        updated.isDeleted = true
                        updated.lastModified = Date()
                        updated.lastModifiedBy = userName
                        self.workOrders[idx] = updated
                    }
                }

                completion(.success(()))
            }
        }
    }
    // END soft delete


    // END
}
