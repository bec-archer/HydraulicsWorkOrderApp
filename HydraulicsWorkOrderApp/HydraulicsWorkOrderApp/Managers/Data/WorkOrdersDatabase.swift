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
    // ───── WO Number Prefix Helper (UTC) ─────
    /// Builds the "YYMMDD" prefix in UTC to match WorkOrderNumberGenerator.
    private static func utcPrefix(from date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let yy = (comps.year ?? 2000) % 100
        let mm = comps.month ?? 1
        let dd = comps.day ?? 1
        return String(format: "%02d%02d%02d", yy, mm, dd)
    }
    // END helper
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
        let creationDate = Date()
        let prefix = WorkOrdersDatabase.utcPrefix(from: creationDate) // e.g., "250814"

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

                let number = WorkOrderNumberGenerator.make(date: creationDate, sequence: nextSeq)
                completion(.success(number))
            }
    }
    // END Generate Next WO Number


    // ───── ADD NEW WORK ORDER TO FIRESTORE ─────
    func addWorkOrder(_ workOrder: WorkOrder, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            // Ensure there's at least one creation note like: "Checked In" by <user> at <timestamp>
            var woForWrite = workOrder
            // ───── Ensure each WO_Item has baseline "Checked In" status ─────
            let authorForBaseline = (woForWrite.lastModifiedBy.isEmpty ? woForWrite.createdBy : woForWrite.lastModifiedBy)
            let baselineTimestamp = woForWrite.timestamp
            let itemsSnapshot = woForWrite.items
            woForWrite.items = itemsSnapshot.map { item in
                var copy = item
                if copy.statusHistory.isEmpty {
                    copy.statusHistory.append(
                        WO_Status(status: "Checked In",
                                  user: authorForBaseline.isEmpty ? "Tech" : authorForBaseline,
                                  timestamp: baselineTimestamp,
                                  notes: nil)
                    )
                }
                return copy
            }
            // ───── END baseline status injection ─────
            if woForWrite.notes.isEmpty {
                let creationNote = WO_Note(
                    user: woForWrite.createdBy,
                    text: "Checked In",
                    timestamp: woForWrite.timestamp
                )
                woForWrite.notes = [creationNote]
            }
    
            // Declare outside so the closure can read it without capture-order issues
            var docRef: DocumentReference?
    
            docRef = try db.collection(collectionName).addDocument(from: woForWrite) { error in

                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Success: update local cache with the Firestore documentID
                DispatchQueue.main.async {
                    var woWithId = woForWrite
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

    // ───── ADD PER-ITEM NOTE ─────
    /// Append a WO_Note to a specific WO_Item inside a WorkOrder document.
    /// - Parameters:
    ///   - woId: Firestore documentID of the WorkOrder (workOrder.id)
    ///   - itemId: UUID of the WO_Item to update
    ///   - note: WO_Note to append
    func addItemNote(woId: String, itemId: UUID, note: WO_Note, completion: @escaping (Result<Void, Error>) -> Void) {
        let docRef = db.collection(collectionName).document(woId)

        docRef.getDocument { [weak self] snap, err in
            guard let self else { return }
            if let err = err { completion(.failure(err)); return }
            guard let snap, snap.exists else {
                return completion(.failure(NSError(domain: "WorkOrdersDatabase",
                                                   code: 404,
                                                   userInfo: [NSLocalizedDescriptionKey: "WorkOrder \(woId) not found"])))
            }

            do {
                var wo = try snap.data(as: WorkOrder.self)
                if wo.id == nil { wo.id = woId } // backfill
                // Find the WO_Item
                guard let idx = wo.items.firstIndex(where: { $0.id == itemId }) else {
                    return completion(.failure(NSError(domain: "WorkOrdersDatabase",
                                                       code: 404,
                                                       userInfo: [NSLocalizedDescriptionKey: "WO_Item \(itemId) not found in WorkOrder \(woId)"])))
                }

                // Append note
                wo.items[idx].notes.append(note)
                wo.lastModified = Date()
                wo.lastModifiedBy = note.user

                try docRef.setData(from: wo, merge: false) { err in
                    if let err = err { completion(.failure(err)); return }

                    // Update local cache so UI lists refresh
                    DispatchQueue.main.async {
                        if let cacheIdx = self.workOrders.firstIndex(where: { $0.id == wo.id }) {
                            self.workOrders[cacheIdx] = wo
                        }
                    }
                    completion(.success(()))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    // END addItemNote

    // ───── UPDATE PER-ITEM STATUS + MIRRORED NOTE ─────
    /// Appends a WO_Status to item.statusHistory and also appends a mirrored WO_Note to item.notes.
    func updateItemStatusAndNote(woId: String,
                                 itemId: UUID,
                                 status: WO_Status,
                                 mirroredNote: WO_Note,
                                 completion: @escaping (Result<Void, Error>) -> Void) {
        let docRef = db.collection(collectionName).document(woId)

        docRef.getDocument { [weak self] snap, err in
            guard let self else { return }
            if let err = err { completion(.failure(err)); return }
            guard let snap, snap.exists else {
                return completion(.failure(NSError(domain: "WorkOrdersDatabase",
                                                   code: 404,
                                                   userInfo: [NSLocalizedDescriptionKey: "WorkOrder \(woId) not found"])))
            }

            do {
                var wo = try snap.data(as: WorkOrder.self)
                if wo.id == nil { wo.id = woId } // backfill

                guard let idx = wo.items.firstIndex(where: { $0.id == itemId }) else {
                    return completion(.failure(NSError(domain: "WorkOrdersDatabase",
                                                       code: 404,
                                                       userInfo: [NSLocalizedDescriptionKey: "WO_Item \(itemId) not found in WorkOrder \(woId)"])))
                }

                // Append status + mirrored system note
                wo.items[idx].statusHistory.append(status)
                wo.items[idx].notes.append(mirroredNote)
                wo.lastModified = Date()
                wo.lastModifiedBy = status.user

                try docRef.setData(from: wo, merge: false) { err in
                    if let err = err { completion(.failure(err)); return }

                    // Update local cache
                    DispatchQueue.main.async {
                        if let cacheIdx = self.workOrders.firstIndex(where: { $0.id == wo.id }) {
                            self.workOrders[cacheIdx] = wo
                        }
                    }
                    completion(.success(()))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    // END updateItemStatusAndNote

    // END
}
