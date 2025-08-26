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
    func addWorkOrder(_ workOrder: WorkOrder, completion: @escaping (Result<String, Error>) -> Void) {
        do {

            
            // Ensure there's at least one creation note like: "Checked In" by <user> at <timestamp>
            var woForWrite = workOrder
            #if DEBUG
            print("🔍 DEBUG: addWorkOrder called for WO: \(workOrder.WO_Number)")
            print("📋 WorkOrder items count: \(workOrder.items.count)")
            for (i, item) in workOrder.items.enumerated() {
                print("  WO Item[\(i)]: id=\(item.id), type='\(item.type)'")
                print("    imageUrls=\(item.imageUrls), thumbUrls=\(item.thumbUrls)")
                print("    reasonsForService=\(item.reasonsForService)")
            }
            #endif
            
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
                    // Update the work order with the actual Firestore document ID for local cache
                    var updatedWO = woForWrite
                    updatedWO.id = docRef?.documentID
                    self.workOrders.append(updatedWO)
                    
                    #if DEBUG
                    print("✅ WorkOrder created successfully: \(updatedWO.WO_Number) with ID: \(updatedWO.id ?? "nil")")
                    print("📊 Total work orders in cache: \(self.workOrders.count)")
                    print("📋 All work orders in cache:")
                    for wo in self.workOrders {
                        print("  - \(wo.WO_Number) (ID: \(wo.id ?? "nil"), Status: \(wo.status), Deleted: \(wo.isDeleted))")
                    }
                    #endif
                }
                completion(.success(docRef?.documentID ?? ""))
            }

            _ = docRef // keep reference alive until closure runs
        } catch {
            completion(.failure(error))
        }
    }


    // ───── FETCH ALL WORK ORDERS FROM FIRESTORE (lenient decode) ─────
    func fetchAllWorkOrders(completion: @escaping (Result<[WorkOrder], Error>) -> Void) {
        // If offline, return cached work orders
        if !NetworkMonitor.shared.isConnected {
            #if DEBUG
            print("📱 Offline mode: Returning cached work orders (\(self.workOrders.count) items)")
            #endif
            completion(.success(self.workOrders))
            return
        }
        
        db.collection(collectionName)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    // If Firestore fails, fall back to cached data
                    #if DEBUG
                    print("⚠️ Firestore fetch failed, using cached data: \(error.localizedDescription)")
                    #endif
                    completion(.success(self.workOrders))
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
                        // Don't manually set @DocumentID - let Firestore handle it
                        // if wo.id == nil { wo.id = doc.documentID } // backfill if custom decoder didn't set it
                        decoded.append(wo)
                    } catch let DecodingError.keyNotFound(key, context) {
                        // ───── Lossy fallback for legacy docs (try once) ─────
                        if let safe = try? self.decodeLossyWorkOrder(from: doc) {
                            decoded.append(safe)
                            #if DEBUG
                            print("ℹ️ Lossy‑decoded legacy WorkOrder \(doc.documentID)")
                            #endif
                            continue
                        }
                        // END lossy fallback
                        // ───── Legacy compat: tolerate missing imageURLs by injecting an empty array and retrying ─────
                        if key.stringValue == "imageURLs" {
                            var raw = doc.data()
                            if raw["imageURLs"] == nil { raw["imageURLs"] = [] }
                            do {
                                let wo = try Firestore.Decoder().decode(WorkOrder.self, from: raw)
                                // Don't manually set @DocumentID - let Firestore handle it
                                // if patched.id == nil { patched.id = doc.documentID }
                                decoded.append(wo)
                                #if DEBUG
                                print("ℹ️ Patched missing imageURLs for \(doc.documentID)")
                                #endif
                                continue
                            } catch {
                                let msg = "Retry with injected imageURLs failed in \(doc.documentID): \(error.localizedDescription)"
                                print("⚠️ WorkOrder decode skipped:", msg)
                                failures.append((doc.documentID, msg))
                            }
                        } else {
                            let msg = "Missing key '\(key.stringValue)' in \(doc.documentID) – \(context.debugDescription)"
                            print("⚠️ WorkOrder decode skipped:", msg)
                            failures.append((doc.documentID, msg))
                        }
                    } catch let DecodingError.valueNotFound(type, context) {
                        // ───── Lossy fallback for valueNotFound (try once) ─────
                        if let safe = try? self.decodeLossyWorkOrder(from: doc) {
                            decoded.append(safe)
                            #if DEBUG
                            print("ℹ️ Lossy‑decoded (valueNotFound) WorkOrder \(doc.documentID)")
                            #endif
                            continue
                        }
                        // END lossy fallback
                        // Some encoders treat a missing array as 'value not found'; apply same legacy patch
                        var raw = doc.data()
                        if raw["imageURLs"] == nil { raw["imageURLs"] = [] }
                        do {
                            let wo = try Firestore.Decoder().decode(WorkOrder.self, from: raw)
                            // Don't manually set @DocumentID - let Firestore handle it
                            // if patched.id == nil { patched.id = doc.documentID }
                            decoded.append(wo)
                            #if DEBUG
                            print("ℹ️ Patched valueNotFound(imageURLs) for \(doc.documentID)")
                            #endif
                        } catch {
                            let msg = "Value of type \(type) not found in \(doc.documentID) – \(context.debugDescription)"
                            print("⚠️ WorkOrder decode skipped:", msg)
                            failures.append((doc.documentID, msg))
                        }
                    } catch {
                        let raw = doc.data()
                        if let built = self.buildWorkOrderFromRaw(raw, id: doc.documentID) {
                            decoded.append(built)
                            #if DEBUG
                            print("ℹ️ Lossy‑built WorkOrder \(doc.documentID) from raw after decode error: \(error.localizedDescription)")
                            #endif
                        } else {
                            let msg = "Unknown decode error in \(doc.documentID): \(error.localizedDescription)"
                            print("⚠️ WorkOrder decode skipped:", msg)
                            failures.append((doc.documentID, msg))
                        }
                    }
                }

                // ───── Normalize & Dedupe before publishing ─────
                // Key by Firestore documentID if present; else WO_Number; else a synthesized local key.
                let keyed: [(String, WorkOrder)] = decoded.map { wo in
                    let key = (wo.id?.isEmpty == false ? wo.id! : (!wo.WO_Number.isEmpty ? "num-\(wo.WO_Number)" : "local-\(UUID().uuidString)"))
                    return (key, wo)
                }
                // Reduce to best candidate per key: prefer the one that has a non‑empty imageURL.
                var bestByKey: [String: WorkOrder] = [:]
                for (k, wo) in keyed {
                    // DON'T overwrite the original imageURL - let WorkOrderPreviewResolver handle this
                    // The original imageURL should be preserved as the authoritative source
                    if let existing = bestByKey[k] {
                        let existingHasPreview = !(existing.imageURL ?? "").isEmpty
                        let candidateHasPreview = !(wo.imageURL ?? "").isEmpty
                        bestByKey[k] = (existingHasPreview ? existing : (candidateHasPreview ? wo : existing))
                    } else {
                        bestByKey[k] = wo
                    }
                }
                // Preserve your original ordering by timestamp desc.
                let deduped = bestByKey.values.sorted(by: { $0.timestamp > $1.timestamp })
                
                // Preserve local deletions when updating cache
                DispatchQueue.main.async {
                    // Create a map of existing work orders by WO_Number for quick lookup
                    let existingByNumber = Dictionary(uniqueKeysWithValues: self.workOrders.map { ($0.WO_Number, $0) })
                    
                    // Merge Firestore data with local deletions
                    let merged = deduped.map { firestoreWO in
                        // If this work order exists in local cache and is marked as deleted, preserve the deletion
                        if let existing = existingByNumber[firestoreWO.WO_Number], existing.isDeleted {
                            var updated = firestoreWO
                            updated.isDeleted = true
                            return updated
                        }
                        return firestoreWO
                    }
                    
                    self.workOrders = merged
                }

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
    // ───── IMAGE URL MERGE + LOCAL PUBLISH (Robust) ─────
    /// Writes new image URLs for a specific WO_Item and ensures the Active list updates immediately.
    /// Now resilient to cache warm‑up and mismatched woId by resolving the parent via itemId and one short retry.
    func applyItemImageURLs(woId: String,
                            itemId: UUID,
                            fullURL: String,
                            thumbURL: String,
                            uploadedBy user: String = "system",
                            completion: @escaping (Result<Void, Error>) -> Void) {

        // Prefer a parent WO that contains this item from the local cache; fall back to the passed woId.
        let effectiveWoId: String = {
            if let local = self.workOrders.first(where: { $0.items.contains(where: { $0.id == itemId }) })?.id, !local.isEmpty {
                return local
            }
            return woId
        }()

        // ───── Lightweight exponential backoff (UI-neutral) ─────
        func retryOrFail(_ remaining: Int, for effectiveWoId: String) {
            guard remaining > 0 else {
                // If we still can't find the work order after retries, try to find it by item ID
                if let foundWO = self.workOrders.first(where: { wo in
                    wo.items.contains(where: { $0.id == itemId })
                }), let woId = foundWO.id, !woId.isEmpty {
                    // Found it by item ID, try again with the correct work order ID
                    attempt(1) // Give it one more try with the correct ID
                    return
                }
                // If still not found, try to find by WO_Number (for newly created work orders)
                if let foundWO = self.workOrders.first(where: { wo in
                    wo.WO_Number == effectiveWoId
                }), let woId = foundWO.id, !woId.isEmpty {
                    // Found it by WO_Number, try again with the correct work order ID
                    attempt(1) // Give it one more try with the correct ID
                    return
                }
                completion(.failure(NSError(
                    domain: "WorkOrdersDatabase",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "WorkOrder \(effectiveWoId) not found"]
                )))
                return
            }
            let attemptIndex = 4 - remaining // 1,2,3
            let delaySeconds = 0.4 * pow(2.0, Double(attemptIndex - 1)) // 0.4, 0.8, 1.6
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                attempt(remaining - 1)
            }
        }

        func attempt(_ remainingRetries: Int) {
            let docRef = db.collection(collectionName).document(effectiveWoId)

            docRef.getDocument { [weak self] snap, err in
                guard let self else { return }
                if let err = err { completion(.failure(err)); return }
                guard let snap, snap.exists else {
                    // Parent WO may not be visible yet; retry calmly.
                    retryOrFail(remainingRetries, for: effectiveWoId)
                    return
                }

                do {
                    var wo = try snap.data(as: WorkOrder.self)
                    if wo.id == nil { wo.id = effectiveWoId }

                    guard let idx = wo.items.firstIndex(where: { $0.id == itemId }) else {
                        // Item not visible in snapshot yet; retry with backoff.
                        retryOrFail(remainingRetries, for: effectiveWoId)
                        return
                    }

                    // ───── Insert URLs with de‑dupe ─────
                    if wo.items[idx].imageUrls.first != fullURL && !wo.items[idx].imageUrls.contains(fullURL) {
                        wo.items[idx].imageUrls.insert(fullURL, at: 0)
                    }

                    // Optional thumbs array support (NO schema change):
                    // If Firestore already has an `items[idx].thumbUrls` array, update it after the main write.
                    let snapData = snap.data()
                    var updatedThumbs: [String]? = nil
                    if
                        let itemsArr = snapData?["items"] as? [[String: Any]],
                        itemsArr.indices.contains(idx),
                        let existingThumbs = itemsArr[idx]["thumbUrls"] as? [String]
                    {
                        var thumbs = existingThumbs
                        if !thumbURL.isEmpty, thumbs.first != thumbURL, !thumbs.contains(thumbURL) {
                            thumbs.insert(thumbURL, at: 0)
                        }
                        updatedThumbs = thumbs
                    }

                    if (wo.imageURL == nil) || (wo.imageURL?.isEmpty == true) {
                        wo.imageURL = thumbURL.isEmpty ? fullURL : thumbURL
                    }

                    wo.lastModified = Date()
                    wo.lastModifiedBy = user
                    // Publish to local cache immediately so the card can render its thumbnail
                    // even if the Firestore write is delayed or retried.
                    self.replaceInCache(wo)

                    try docRef.setData(from: wo, merge: false) { err in
                        if let err = err {
                            // Even if the write errored, keep the UI responsive with the resolved preview.
                            self.replaceInCache(wo)
                            completion(.failure(err))
                            return
                        }
                        // If a thumbs array existed in Firestore, write the updated value back non‑fatally.
                        if let thumbs = updatedThumbs {
                            let path = "items.\(idx).thumbUrls"
                            docRef.updateData([path: thumbs]) { _ in /* ignore errors to keep UX unchanged */ }
                        }
                        self.replaceInCache(wo) // publish for UI refresh
                        completion(.success(()))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }

        // Kick off with three retries available to smooth over race conditions
        attempt(3)
    }
    // END image URL merge (robust)

    // ───── Lossy decode shim for legacy docs ─────
    /// Attempts to decode a WorkOrder while tolerating missing optional fields like imageUrls.
    private func decodeLossyWorkOrder(from doc: DocumentSnapshot) throws -> WorkOrder {
        #if DEBUG
        print("🔍 DEBUG: decodeLossyWorkOrder called for document: \(doc.documentID)")
        #endif
        struct WO_LOSSY: Decodable {
            let id: String?
            let createdBy: String?
            let phoneNumber: String?
            // Customer fields (may be absent on legacy docs)
            let customerId: String?
            let customerName: String?
            let customerPhone: String?
            let WO_Type: String?
            let imageURL: String?
            let imageURLs: [String]?   // 🆕 tolerate top-level imageURLs if present
            let timestamp: Timestamp?
            let status: String?
            let WO_Number: String?
            let flagged: Bool?
            let dropdowns: [String:String]?
            let dropdownSchemaVersion: Int?
            let lastModified: Timestamp?
            let lastModifiedBy: String?
            let notes: [WO_Note]?
            let items: [ITEM_LOSSY]?
            let tagBypassReason: String?
            let isDeleted: Bool?

            struct ITEM_LOSSY: Decodable {
                let id: UUID?
                let tagId: String?
                let type: String?
                let dropdowns: [String:String]?
                let reasonsForService: [String]?
                let reasonNotes: String?
                let completedReasons: [String]?
                let imageUrls: [String]?
                let thumbUrls: [String]?
                let lastModified: Date?
                let dropdownSchemaVersion: Int?
                let lastModifiedBy: String?
                let statusHistory: [WO_Status]?
                let notes: [WO_Note]?
                // Additional fields not in CodingKeys but needed for full item reconstruction
                let testResult: String?
                let partsUsed: String?
                let hoursWorked: String?
                let cost: String?
                let assignedTo: String?
                let isFlagged: Bool?
                let tagReplacementHistory: [TagReplacement]?
            }
        }

        let lossy = try doc.data(as: WO_LOSSY.self)

        #if DEBUG
        print("🔍 DEBUG: Lossy decode successful, items count: \(lossy.items?.count ?? 0)")
        #endif

        var itemsAccum: [WO_Item] = []
        for it in (lossy.items ?? []) {
            // Break up the large initializer into simple locals to help the type checker
            let safeItemId             = it.id ?? UUID()
            let safeTagId              = it.tagId
            let safeType               = it.type ?? "Unknown"
            let safeDropdowns          = it.dropdowns ?? [:]
            let safeReasons            = it.reasonsForService ?? []
            let safeReasonNotes        = it.reasonNotes
            let safeCompletedReasons   = it.completedReasons ?? []
            let safeImageUrls          = it.imageUrls ?? []
            let safeThumbUrls          = it.thumbUrls ?? []
            let safeLastModified       = it.lastModified ?? Date()
            let safeDropdownSchemaVer  = it.dropdownSchemaVersion ?? 1
            let safeLastModifiedBy     = it.lastModifiedBy
            let safeStatusHistory      = it.statusHistory ?? []
            let safeNotes              = it.notes ?? []
            let safeTestResult         = it.testResult
            let safePartsUsed          = it.partsUsed
            let safeHoursWorked        = it.hoursWorked
            let safeCost               = it.cost
            let safeAssignedTo         = it.assignedTo ?? ""
            let safeIsFlagged          = it.isFlagged ?? false
            let safeTagReplacementHist = it.tagReplacementHistory

            // Create item with all fields including notes and lastModified
            var item = WO_Item()
            item.id = safeItemId
            item.tagId = safeTagId
            item.type = safeType
            item.dropdowns = safeDropdowns
            item.reasonsForService = safeReasons
            item.reasonNotes = safeReasonNotes
            item.completedReasons = safeCompletedReasons
            item.imageUrls = safeImageUrls
            item.thumbUrls = safeThumbUrls
            item.lastModified = safeLastModified
            item.dropdownSchemaVersion = safeDropdownSchemaVer
            item.lastModifiedBy = safeLastModifiedBy
            item.statusHistory = safeStatusHistory
            item.notes = safeNotes
            item.testResult = safeTestResult
            item.partsUsed = safePartsUsed
            item.hoursWorked = safeHoursWorked
            item.cost = safeCost
            item.assignedTo = safeAssignedTo
            item.isFlagged = safeIsFlagged
            item.tagReplacementHistory = safeTagReplacementHist
            itemsAccum.append(item)
        }
        let safeItems: [WO_Item] = itemsAccum

        #if DEBUG
        print("🔍 DEBUG: Built \(safeItems.count) items from lossy decode")
        #endif

        // Break up the large initializer to help the type checker
        // Don't manually set @DocumentID - let Firestore handle it
        let safeId: String?      = nil
        let safeCreatedBy        = lossy.createdBy ?? ""
        let safePhone            = lossy.phoneNumber ?? ""
        let safeCustomerId        = lossy.customerId ?? ""
        let safeCustomerName      = lossy.customerName ?? ""
        let safeCustomerPhone     = lossy.customerPhone ?? ""
        // Prefer explicit customerPhone; fall back to legacy phoneNumber if present
        let finalCustomerPhone = safeCustomerPhone.isEmpty ? safePhone : safeCustomerPhone
        let safeType             = lossy.WO_Type ?? ""
        let safeImageURL         = lossy.imageURL
        let safeImageURLs        = lossy.imageURLs ?? []  // 🆕 ensure initializer label match
        let safeTimestamp        = (lossy.timestamp?.dateValue()) ?? Date()
        let safeStatus           = lossy.status ?? "Checked In"
        let safeNumber           = lossy.WO_Number ?? ""
        let safeFlagged          = lossy.flagged ?? false
        let safeDropdowns        = lossy.dropdowns ?? [:]
        let safeSchemaVersion    = lossy.dropdownSchemaVersion ?? 1
        let safeLastModified     = (lossy.lastModified?.dateValue()) ?? Date()
        let safeLastModifiedBy   = lossy.lastModifiedBy ?? ""
        let safeNotes            = lossy.notes ?? []
        let safeTagBypassReason  = lossy.tagBypassReason
        let safeIsDeleted        = lossy.isDeleted ?? false
        
        // Build in two steps to help the type checker
        var builtWO = WorkOrder(
            id: safeId,
            createdBy: safeCreatedBy,
            customerId: safeCustomerId,
            customerName: safeCustomerName,
            customerPhone: finalCustomerPhone,
            WO_Type: safeType,
            imageURL: safeImageURL,
            imageURLs: safeImageURLs, // 🆕 match WorkOrder signature
            timestamp: safeTimestamp,
            status: safeStatus,
            WO_Number: safeNumber,
            flagged: safeFlagged,
            tagId: nil,
            estimatedCost: nil,
            finalCost: nil,
            dropdowns: safeDropdowns,
            dropdownSchemaVersion: safeSchemaVersion,
            lastModified: safeLastModified,
            lastModifiedBy: safeLastModifiedBy,
            tagBypassReason: safeTagBypassReason, // 🧭 place before isDeleted per signature
            isDeleted: safeIsDeleted,
            notes: safeNotes,
            items: safeItems
        )
        // If the top‑level preview is missing, try the first item's image as a fallback.
        if (builtWO.imageURL == nil) || (builtWO.imageURL?.isEmpty == true) {
            builtWO.imageURL = safeItems.first?.imageUrls.first
        }
        return builtWO
    }
    // END lossy decode shim

    // ───── Minimal lossy builder (raw dictionary → WorkOrder) ─────
    /// Used when Firebase decoding fails with "data isn’t in the correct format".
    /// Maps whatever fields we can and defaults the rest so the card still renders.
    private func buildWorkOrderFromRaw(_ raw: [String: Any], id: String) -> WorkOrder? {
        let s = { (k: String) -> String? in raw[k] as? String }
        let b = { (k: String) -> Bool? in raw[k] as? Bool }
        let i = { (k: String) -> Int? in raw[k] as? Int }
        let ts = { (k: String) -> Date? in
            if let t = raw[k] as? Timestamp { return t.dateValue() }
            if let d = raw[k] as? Date { return d }
            return nil
        }

        let createdBy  = s("createdBy") ?? ""
        let phone      = s("customerPhone") ?? s("phoneNumber") ?? ""
        let woType     = s("WO_Type") ?? ""
        let imageURL   = s("imageURL")
        let timestamp  = ts("timestamp") ?? Date()
        let status     = s("status") ?? "Checked In"
        let number     = s("WO_Number") ?? ""
        let flagged    = b("flagged") ?? false
        let lastMod    = ts("lastModified") ?? timestamp
        let lastBy     = s("lastModifiedBy") ?? createdBy
        let custId     = s("customerId") ?? ""
        let custName   = s("customerName") ?? ""
        let bypass     = s("tagBypassReason")
        let isDeleted  = b("isDeleted") ?? false
        let dropdowns  = raw["dropdowns"] as? [String: String] ?? [:]
        let schemaVer  = i("dropdownSchemaVersion") ?? 1

        var items: [WO_Item] = []
        if let arr = raw["items"] as? [[String: Any]] {
            #if DEBUG
            print("🔍 DEBUG: buildWorkOrderFromRaw - Found \(arr.count) items in raw data")
            #endif
            for anyItem in arr {
                let itemId = (anyItem["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
                let tagId  = anyItem["tagId"] as? String
                let urls   = anyItem["imageUrls"] as? [String]
                             ?? anyItem["imageURLs"] as? [String]
                             ?? []
                let thumbUrls = anyItem["thumbUrls"] as? [String] ?? []
                let type   = anyItem["type"] as? String ?? "Unknown"
                let dd     = anyItem["dropdowns"] as? [String: String] ?? [:]
                let ddv    = anyItem["dropdownSchemaVersion"] as? Int ?? schemaVer
                let reasons = anyItem["reasonsForService"] as? [String] ?? []
                let reasonNotes = anyItem["reasonNotes"] as? String
                let completedReasons = anyItem["completedReasons"] as? [String] ?? []
                let assigned = anyItem["assignedTo"] as? String ?? ""
                let isFlagged = anyItem["isFlagged"] as? Bool ?? false
                let notes = anyItem["notes"] as? [WO_Note] ?? []
                let lastModified = {
                    if let timestamp = anyItem["lastModified"] as? Timestamp {
                        return timestamp.dateValue()
                    } else if let date = anyItem["lastModified"] as? Date {
                        return date
                    } else {
                        return Date()
                    }
                }()
                let lastModifiedBy = anyItem["lastModifiedBy"] as? String

                let item = WO_Item(
                    id: itemId,
                    tagId: tagId,
                    imageUrls: urls,
                    thumbUrls: thumbUrls,
                    type: type,
                    dropdowns: dd,
                    dropdownSchemaVersion: ddv,
                    reasonsForService: reasons,
                    reasonNotes: reasonNotes,
                    completedReasons: completedReasons,
                    statusHistory: [],
                    testResult: nil,
                    partsUsed: nil,
                    hoursWorked: nil,
                    cost: nil,
                    assignedTo: assigned,
                    isFlagged: isFlagged,
                    tagReplacementHistory: nil
                )
                
                // Set additional fields that aren't in the initializer
                var mutableItem = item
                mutableItem.notes = notes
                mutableItem.lastModified = lastModified
                mutableItem.lastModifiedBy = lastModifiedBy
                items.append(mutableItem)
            }
        }
        #if DEBUG
        print("🔍 DEBUG: buildWorkOrderFromRaw - Built \(items.count) items for work order")
        #endif

        let wo = WorkOrder(
            id: nil, // Don't manually set @DocumentID - let Firestore handle it
            createdBy: createdBy,
            customerId: custId,
            customerName: custName,
            customerPhone: phone,
            WO_Type: woType,
            imageURL: (imageURL ?? {
                if let arr = raw["items"] as? [[String: Any]] {
                    if let thumbs = arr.first?["thumbUrls"] as? [String], let first = thumbs.first { return first }
                    if let images = arr.first?["imageUrls"] as? [String], let first = images.first { return first }
                    if let images2 = arr.first?["imageURLs"] as? [String], let first = images2.first { return first }
                }
                return nil
            }()),
            imageURLs: [],
            timestamp: timestamp,
            status: status,
            WO_Number: number,
            flagged: flagged,
            tagId: nil,
            estimatedCost: nil,
            finalCost: nil,
            dropdowns: dropdowns,
            dropdownSchemaVersion: schemaVer,
            lastModified: lastMod,
            lastModifiedBy: lastBy,
            tagBypassReason: bypass,
            isDeleted: isDeleted,
            notes: [],
            items: items
        )
        return wo
    }
    // END minimal lossy builder

    // ───── LOCAL CACHE REPLACEMENT (UI REFRESH) ─────
    /// Replaces the matching WorkOrder in the published cache (by documentID) on the main queue.
    /// This triggers SwiftUI to re-render ActiveWorkOrdersView and its cards.
    private func replaceInCache(_ updated: WorkOrder) {
        DispatchQueue.main.async {
            var wo = updated

            // ───── Ensure we always have a stable identifier for SwiftUI lists ─────
            // Don't manually set @DocumentID - let Firestore handle it
            // We'll use WO_Number for local identification instead

            // ───── Opportunistic preview fill to avoid spinner ─────
            if (wo.imageURL == nil) || (wo.imageURL?.isEmpty == true) {
                // Prefer thumbnail URL for better performance
                if let candidate = wo.items.first?.thumbUrls.first {
                    wo.imageURL = candidate
                } else if let candidate = wo.items.first?.imageUrls.first {
                    wo.imageURL = candidate
                }
            }

            // Try to replace by Firestore id first
            if let idxById = self.workOrders.firstIndex(where: { $0.id == wo.id }) {
                self.workOrders[idxById] = wo
                return
            }

            // If id didn’t match (legacy/local), try to match by WO_Number to prevent duplicates
            if !wo.WO_Number.isEmpty, let idxByNumber = self.workOrders.firstIndex(where: { $0.WO_Number == wo.WO_Number }) {
                self.workOrders[idxByNumber] = wo
                return
            }

            // Otherwise insert at the top
            self.workOrders.insert(wo, at: 0)
        }
    }
    // END local cache replacement
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

    // ───── DELETE LEGACY WORK ORDER (by WO_Number) ─────
    /// Finds and soft deletes a legacy work order by its WO_Number when document ID is not available.
    /// This is used for work orders created before proper ID management was implemented.
    func deleteLegacyWorkOrder(woNumber: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Query Firestore to find the work order by WO_Number
        db.collection(collectionName)
            .whereField("WO_Number", isEqualTo: woNumber)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let docs = snapshot?.documents, !docs.isEmpty else {
                    completion(.failure(NSError(domain: "WorkOrdersDatabase",
                                                code: 404,
                                                userInfo: [NSLocalizedDescriptionKey: "WorkOrder with WO_Number \(woNumber) not found in Firestore"])))
                    return
                }
                
                // Use the first document found (should be unique by WO_Number)
                let docRef = docs[0].reference
                
                // Apply soft delete
                let updates: [String: Any] = [
                    "isDeleted": true,
                    "lastModified": Date(),
                    "lastModifiedBy": "system"
                ]
                
                docRef.updateData(updates) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
    // END delete legacy work order

    // ───── FIND WORK ORDER ID BY WO_NUMBER ─────
    /// Finds a work order's Firestore document ID by its WO_Number
    func findWorkOrderId(byWONumber woNumber: String, completion: @escaping (Result<String, Error>) -> Void) {
        db.collection(collectionName)
            .whereField("WO_Number", isEqualTo: woNumber)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let docs = snapshot?.documents, !docs.isEmpty else {
                    completion(.failure(NSError(domain: "WorkOrdersDatabase",
                                              code: 404,
                                              userInfo: [NSLocalizedDescriptionKey: "WorkOrder with WO_Number \(woNumber) not found in Firestore"])))
                    return
                }
                
                // Use the first document found (should be unique by WO_Number)
                let docId = docs[0].documentID
                
                // Update local cache with the found ID
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if let idx = self.workOrders.firstIndex(where: { $0.WO_Number == woNumber }) {
                        var updated = self.workOrders[idx]
                        updated.id = docId
                        self.workOrders[idx] = updated
                    }
                }
                
                completion(.success(docId))
            }
    }
    // END find work order id

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
                // Don't manually set @DocumentID - let Firestore handle it
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
                        #if DEBUG
                        print("🔄 WorkOrdersDatabase: Updating cache for WO \(wo.WO_Number) (addItemNote)")
                        print("   - Firestore ID: \(wo.id ?? "nil")")
                        print("   - Current cache size: \(self.workOrders.count)")
                        #endif
                        
                        // Try to find by WO_Number first (more reliable), then by ID as fallback
                        if let cacheIdx = self.workOrders.firstIndex(where: { $0.WO_Number == wo.WO_Number }) {
                            self.workOrders[cacheIdx] = wo
                            #if DEBUG
                            print("   ✅ Updated by WO_Number at index \(cacheIdx)")
                            #endif
                        } else if let woId = wo.id, !woId.isEmpty, let cacheIdx = self.workOrders.firstIndex(where: { $0.id == woId }) {
                            self.workOrders[cacheIdx] = wo
                            #if DEBUG
                            print("   ✅ Updated by ID at index \(cacheIdx)")
                            #endif
                        } else {
                            #if DEBUG
                            print("   ⚠️ Work order not found in cache - adding to cache")
                            #endif
                            // If not found, add it to the cache
                            self.workOrders.append(wo)
                        }
                        
                        // Post notification to trigger UI updates
                        NotificationCenter.default.post(
                            name: .WorkOrderSaved,
                            object: wo.id,
                            userInfo: ["WO_Number": wo.WO_Number]
                        )
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
                // Don't manually set @DocumentID - let Firestore handle it

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
                        #if DEBUG
                        print("🔄 WorkOrdersDatabase: Updating cache for WO \(wo.WO_Number)")
                        print("   - Firestore ID: \(wo.id ?? "nil")")
                        print("   - Current cache size: \(self.workOrders.count)")
                        #endif
                        
                        // Try to find by WO_Number first (more reliable), then by ID as fallback
                        if let cacheIdx = self.workOrders.firstIndex(where: { $0.WO_Number == wo.WO_Number }) {
                            self.workOrders[cacheIdx] = wo
                            #if DEBUG
                            print("   ✅ Updated by WO_Number at index \(cacheIdx)")
                            #endif
                        } else if let woId = wo.id, !woId.isEmpty, let cacheIdx = self.workOrders.firstIndex(where: { $0.id == woId }) {
                            self.workOrders[cacheIdx] = wo
                            #if DEBUG
                            print("   ✅ Updated by ID at index \(cacheIdx)")
                            #endif
                        } else {
                            #if DEBUG
                            print("   ⚠️ Work order not found in cache - adding to cache")
                            #endif
                            // If not found, add it to the cache
                            self.workOrders.append(wo)
                        }
                        
                        // Post notification to trigger UI updates
                        NotificationCenter.default.post(
                            name: .WorkOrderSaved,
                            object: wo.id,
                            userInfo: ["WO_Number": wo.WO_Number]
                        )
                    }
                    completion(.success(()))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    // END updateItemStatusAndNote

    // ───── UPDATE COMPLETED REASONS + MIRRORED NOTE ─────
    /// Updates the completedReasons array and adds a note about the completion.
    func updateCompletedReasons(woId: String,
                               itemId: UUID,
                               completedReasons: [String],
                               note: WO_Note,
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

                guard let idx = wo.items.firstIndex(where: { $0.id == itemId }) else {
                    return completion(.failure(NSError(domain: "WorkOrdersDatabase",
                                                       code: 404,
                                                       userInfo: [NSLocalizedDescriptionKey: "WO_Item \(itemId) not found in WorkOrder \(woId)"])))
                }

                // Update completed reasons and add note
                wo.items[idx].completedReasons = completedReasons
                wo.items[idx].notes.append(note)
                wo.lastModified = Date()
                wo.lastModifiedBy = note.user

                try docRef.setData(from: wo, merge: false) { err in
                    if let err = err { completion(.failure(err)); return }

                    // Update local cache
                    DispatchQueue.main.async {
                        #if DEBUG
                        print("🔄 WorkOrdersDatabase: Updating completed reasons for WO \(wo.WO_Number)")
                        print("   - Firestore ID: \(wo.id ?? "nil")")
                        print("   - Completed reasons: \(completedReasons)")
                        #endif
                        
                        // Try to find by WO_Number first (more reliable), then by ID as fallback
                        if let cacheIdx = self.workOrders.firstIndex(where: { $0.WO_Number == wo.WO_Number }) {
                            self.workOrders[cacheIdx] = wo
                            #if DEBUG
                            print("   ✅ Updated by WO_Number at index \(cacheIdx)")
                            #endif
                        } else if let woId = wo.id, !woId.isEmpty, let cacheIdx = self.workOrders.firstIndex(where: { $0.id == woId }) {
                            self.workOrders[cacheIdx] = wo
                            #if DEBUG
                            print("   ✅ Updated by ID at index \(cacheIdx)")
                            #endif
                        } else {
                            #if DEBUG
                            print("   ⚠️ Work order not found in cache - adding to cache")
                            #endif
                            // If not found, add it to the cache
                            self.workOrders.append(wo)
                        }
                        
                        // Post notification to trigger UI updates
                        NotificationCenter.default.post(
                            name: .WorkOrderSaved,
                            object: wo.id,
                            userInfo: ["WO_Number": wo.WO_Number]
                        )
                    }
                    completion(.success(()))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    // END updateCompletedReasons

    // END
}
