//
//  WorkOrdersDatabase.swift
//  HydraulicsWorkOrderApp
//
//  Firebase Firestore integration for work orders
//
import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
final class WorkOrdersDatabase: ObservableObject {
    static let shared = WorkOrdersDatabase()
    
    @Published var workOrders: [WorkOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let collectionName = "workOrders"
    
    private init() {}
    
    // MARK: - Minimal Placeholder Methods
    
    func addWorkOrder(_ workOrder: WorkOrder) async throws {
        print("🔍 DEBUG: WorkOrdersDatabase.addWorkOrder() called")
        print("🔍 DEBUG: WorkOrder to add:")
        print("  - ID: \(workOrder.id)")
        print("  - Work Order Number: \(workOrder.workOrderNumber)")
        print("  - Customer: \(workOrder.customerName)")
        print("  - Status: \(workOrder.status)")
        print("  - Items count: \(workOrder.items.count)")
        print("  - Current workOrders count: \(workOrders.count)")
        
        do {
            // Convert WorkOrder to Firestore document
            let workOrderData = try encodeWorkOrderToFirestore(workOrder)
            
            // Save to Firebase Firestore
            print("🔍 DEBUG: Saving work order to Firebase Firestore...")
            try await db.collection(collectionName).document(workOrder.id).setData(workOrderData)
            print("✅ DEBUG: Work order saved to Firebase Firestore successfully!")
            
            // Add to local array for immediate UI update
            workOrders.append(workOrder)
            print("✅ DEBUG: WorkOrder added to local array")
            print("🔍 DEBUG: New workOrders count: \(workOrders.count)")
            
        } catch {
            print("❌ DEBUG: Error saving work order to Firebase: \(error)")
            print("❌ DEBUG: Error localized description: \(error.localizedDescription)")
            throw error
        }
    }
    
    func updateWorkOrder(_ workOrder: WorkOrder) async throws {
        print("🔍 DEBUG: updateWorkOrder called for WO: \(workOrder.workOrderNumber)")
        
        do {
            // Save to Firebase Firestore
            print("🔍 DEBUG: Saving work order to Firebase Firestore...")
            let data = try encodeWorkOrderToFirestore(workOrder)
            try await db.collection(collectionName).document(workOrder.id).setData(data)
            print("✅ DEBUG: Successfully saved work order to Firebase Firestore")
            
            // Update local array
            if let index = workOrders.firstIndex(where: { $0.id == workOrder.id }) {
                workOrders[index] = workOrder
                print("🔍 DEBUG: Updated local workOrders array")
            }
            
        } catch {
            print("❌ DEBUG: Failed to save work order to Firebase: \(error)")
            throw error
        }
    }
    
    func deleteWorkOrder(_ workOrder: WorkOrder) async throws {
        workOrders.removeAll { $0.id == workOrder.id }
    }
    
    func deleteWorkOrder(_ workOrderId: String) async throws {
        workOrders.removeAll { $0.id == workOrderId }
    }
    
    func loadWorkOrders() async {
        isLoading = false
    }
    
    func findWorkOrderId(byWONumber woNumber: String, completion: @escaping (Result<String, Error>) -> Void) {
        if let workOrder = workOrders.first(where: { $0.workOrderNumber == woNumber }) {
            completion(.success(workOrder.id))
        } else {
            completion(.failure(NSError(domain: "NotImplemented", code: 0)))
        }
    }
    
    func deleteLegacyWorkOrder(woNumber: String, completion: @escaping (Result<Void, Error>) -> Void) {
        workOrders.removeAll { $0.workOrderNumber == woNumber }
        completion(.success(()))
    }
    
    func fetchWorkOrder(woId: String, completion: @escaping (Result<WorkOrder, Error>) -> Void) {
        if let workOrder = workOrders.first(where: { $0.id == woId }) {
            completion(.success(workOrder))
        } else {
            completion(.failure(NSError(domain: "NotImplemented", code: 0)))
        }
    }
    
    func fetchWorkOrdersByCustomer(customerId: String, completion: @escaping (Result<[WorkOrder], Error>) -> Void) {
        let customerWorkOrders = workOrders.filter { $0.customerId == customerId }
        completion(.success(customerWorkOrders))
    }
    
    func addItemNote(_ note: WO_Note, to workOrderId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = workOrders.firstIndex(where: { $0.id == workOrderId }) {
            workOrders[index].notes.append(note)
            completion(.success(()))
        } else {
            completion(.failure(NSError(domain: "NotImplemented", code: 0)))
        }
    }
    
    func updateItemStatusAndNote(_ status: String, note: WO_Note, for workOrderId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = workOrders.firstIndex(where: { $0.id == workOrderId }) {
            workOrders[index].status = status
            workOrders[index].notes.append(note)
            completion(.success(()))
        } else {
            completion(.failure(NSError(domain: "NotImplemented", code: 0)))
        }
    }
    
    func updateCompletedReasons(_ reasons: [String], for workOrderId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
    
    func applyItemImageURLs(_ imageURLs: [String], _ thumbURLs: [String], to workOrderId: String, itemId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
    
    func setWorkOrderPreviewIfEmpty(containingItem itemId: UUID, previewURL: String) {
        // Placeholder implementation
    }
    
    func scheduleWOPreviewPersistRetry(containingItem itemId: UUID, url: String, delay: TimeInterval) {
        // Placeholder implementation
    }
    
    func generateNextWONumber(completion: @escaping (Result<String, Error>) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        let today = dateFormatter.string(from: Date())
        let existingNumbers = workOrders.compactMap { $0.workOrderNumber }
        let todayNumbers = existingNumbers.filter { $0.hasPrefix(today) }
        let nextNumber = todayNumbers.count + 1
        let woNumber = "\(today)-\(String(format: "%03d", nextNumber))"
        completion(.success(woNumber))
    }
    
    func softDelete(_ workOrder: WorkOrder, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = workOrders.firstIndex(where: { $0.id == workOrder.id }) {
            workOrders[index].isDeleted = true
            completion(.success(()))
        } else {
            completion(.failure(NSError(domain: "NotImplemented", code: 0)))
        }
    }
    
    func fetchAllWorkOrders(completion: @escaping (Result<[WorkOrder], Error>) -> Void) {
        completion(.success(workOrders))
    }
    
    // MARK: - Tag Scanning Support
    
    /// Find a work order item by its asset tag ID
    func findWorkOrderItemByTagId(_ tagId: String, completion: @escaping (Result<(WorkOrder, WO_Item, Int), Error>) -> Void) {
        print("🔍 DEBUG: Searching for work order item with tag ID: \(tagId)")
        
        // Search through all work orders and their items
        for workOrder in workOrders {
            for (index, item) in workOrder.items.enumerated() {
                if let itemTagId = item.assetTagId, itemTagId == tagId {
                    print("✅ DEBUG: Found work order item with tag ID \(tagId) in work order \(workOrder.workOrderNumber)")
                    completion(.success((workOrder, item, index)))
                    return
                }
            }
        }
        
        print("❌ DEBUG: No work order item found with tag ID: \(tagId)")
        completion(.failure(NSError(domain: "TagNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "No work order item found with tag ID: \(tagId)"])))
    }
    
    func getAllWorkOrders() async throws -> [WorkOrder] {
        print("🔍 DEBUG: WorkOrdersDatabase.getAllWorkOrders() called")
        
        do {
            // Load from Firebase Firestore
            print("🔍 DEBUG: Loading work orders from Firebase Firestore...")
            let snapshot = try await db.collection(collectionName).getDocuments()
            
            var firebaseWorkOrders: [WorkOrder] = []
            for document in snapshot.documents {
                do {
                    let workOrder = try decodeWorkOrderFromFirestore(document.data(), id: document.documentID)
                    firebaseWorkOrders.append(workOrder)
                } catch {
                    print("⚠️ DEBUG: Failed to decode work order \(document.documentID): \(error)")
                }
            }
            
            print("✅ DEBUG: Loaded \(firebaseWorkOrders.count) work orders from Firebase Firestore")
            
            // Update local array
            workOrders = firebaseWorkOrders
            
            // Debug each work order
            for (index, workOrder) in workOrders.enumerated() {
                print("🔍 DEBUG: WorkOrder[\(index)]: \(workOrder.workOrderNumber) - \(workOrder.customerName) - \(workOrder.status)")
            }
            
            return workOrders
            
        } catch {
            print("❌ DEBUG: Error loading work orders from Firebase: \(error)")
            print("❌ DEBUG: Returning local array as fallback")
            return workOrders
        }
    }
    
    func migrateExistingWorkOrdersToHaveWOItemIds(completion: @escaping (Result<Void, Error>) -> Void) {
        // Placeholder implementation - migration not needed in placeholder
        completion(.success(()))
    }
    
    static func utcPrefix(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        return dateFormatter.string(from: date)
    }
    
    // MARK: - Firebase Firestore Encoding/Decoding
    
    private func encodeWorkOrderToFirestore(_ workOrder: WorkOrder) throws -> [String: Any] {
        var data: [String: Any] = [:]
        
        // Basic work order fields
        data["id"] = workOrder.id
        data["createdBy"] = workOrder.createdBy
        data["customerId"] = workOrder.customerId
        data["customerName"] = workOrder.customerName
        data["customerCompany"] = workOrder.customerCompany ?? ""
        data["customerEmail"] = workOrder.customerEmail ?? ""
        data["customerTaxExempt"] = workOrder.customerTaxExempt
        data["customerPhone"] = workOrder.customerPhone
        data["customerEmojiTag"] = workOrder.customerEmojiTag ?? ""
        data["workOrderType"] = workOrder.workOrderType
        data["primaryImageURL"] = workOrder.primaryImageURL ?? ""
        data["timestamp"] = Timestamp(date: workOrder.timestamp)
        data["status"] = workOrder.status
        data["workOrderNumber"] = workOrder.workOrderNumber
        data["flagged"] = workOrder.flagged
        data["assetTagId"] = workOrder.assetTagId ?? ""
        data["estimatedCost"] = workOrder.estimatedCost ?? ""
        data["finalCost"] = workOrder.finalCost ?? ""
        data["dropdowns"] = workOrder.dropdowns
        data["dropdownSchemaVersion"] = workOrder.dropdownSchemaVersion
        data["lastModified"] = Timestamp(date: workOrder.lastModified)
        data["lastModifiedBy"] = workOrder.lastModifiedBy
        data["tagBypassReason"] = workOrder.tagBypassReason ?? ""
        data["isDeleted"] = workOrder.isDeleted
        data["syncStatus"] = workOrder.syncStatus
        data["lastSyncDate"] = workOrder.lastSyncDate != nil ? Timestamp(date: workOrder.lastSyncDate!) : nil
        
        // Encode items
        var itemsData: [[String: Any]] = []
        for item in workOrder.items {
            var itemData: [String: Any] = [:]
            itemData["id"] = item.id.uuidString
            itemData["type"] = item.type
            itemData["imageUrls"] = item.imageUrls
            itemData["thumbUrls"] = item.thumbUrls
            itemData["reasonsForService"] = item.reasonsForService
            itemData["completedReasons"] = item.completedReasons
            itemData["reasonNotes"] = item.reasonNotes ?? ""
            itemData["assetTagId"] = item.assetTagId ?? ""
            itemData["dropdowns"] = item.dropdowns
            itemData["statusHistory"] = item.statusHistory.map { status in
                [
                    "status": status.status,
                    "timestamp": Timestamp(date: status.timestamp),
                    "user": status.user,
                    "notes": status.notes ?? ""
                ]
            }
            itemData["notes"] = item.notes.map { note in
                [
                    "text": note.text,
                    "timestamp": Timestamp(date: note.timestamp),
                    "user": note.user,
                    "workOrderId": note.workOrderId,
                    "itemId": note.itemId ?? "",
                    "imageUrls": note.imageUrls
                ]
            }
            itemData["lastModified"] = Timestamp(date: item.lastModified)
            itemData["lastModifiedBy"] = item.lastModifiedBy ?? ""
            itemData["tagReplacementHistory"] = item.tagReplacementHistory?.map { replacement in
                [
                    "oldTagId": replacement.oldTagId,
                    "newTagId": replacement.newTagId,
                    "reason": replacement.reason ?? "",
                    "timestamp": Timestamp(date: replacement.timestamp),
                    "replacedBy": replacement.replacedBy
                ]
            } ?? []
            
            itemsData.append(itemData)
        }
        data["items"] = itemsData
        
        // Encode notes
        var notesData: [[String: Any]] = []
        for note in workOrder.notes {
            var noteData: [String: Any] = [:]
            noteData["text"] = note.text
            noteData["timestamp"] = Timestamp(date: note.timestamp)
            noteData["user"] = note.user
            noteData["workOrderId"] = note.workOrderId
            noteData["itemId"] = note.itemId ?? ""
            notesData.append(noteData)
        }
        data["notes"] = notesData
        
        return data
    }
    
    private func decodeWorkOrderFromFirestore(_ data: [String: Any], id: String) throws -> WorkOrder {
        // Decode basic fields
        let createdBy = data["createdBy"] as? String ?? ""
        let customerId = data["customerId"] as? String ?? ""
        let customerName = data["customerName"] as? String ?? ""
        let customerCompany = data["customerCompany"] as? String
        let customerEmail = data["customerEmail"] as? String
        let customerTaxExempt = data["customerTaxExempt"] as? Bool ?? false
        let customerPhone = data["customerPhone"] as? String ?? ""
        let customerEmojiTag = data["customerEmojiTag"] as? String
        let workOrderType = data["workOrderType"] as? String ?? ""
        let primaryImageURL = data["primaryImageURL"] as? String
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let status = data["status"] as? String ?? ""
        let workOrderNumber = data["workOrderNumber"] as? String ?? ""
        let flagged = data["flagged"] as? Bool ?? false
        let assetTagId = data["assetTagId"] as? String
        let estimatedCost = data["estimatedCost"] as? String
        let finalCost = data["finalCost"] as? String
        let dropdowns = data["dropdowns"] as? [String: String] ?? [:]
        let dropdownSchemaVersion = data["dropdownSchemaVersion"] as? Int ?? 1
        let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? Date()
        let lastModifiedBy = data["lastModifiedBy"] as? String ?? ""
        let tagBypassReason = data["tagBypassReason"] as? String
        let isDeleted = data["isDeleted"] as? Bool ?? false
        let syncStatus = data["syncStatus"] as? String ?? ""
        let lastSyncDate = (data["lastSyncDate"] as? Timestamp)?.dateValue()
        
        // Decode items
        var items: [WO_Item] = []
        if let itemsData = data["items"] as? [[String: Any]] {
            for itemData in itemsData {
                let item = try decodeWOItemFromFirestore(itemData)
                items.append(item)
            }
        }
        
        // Decode notes
        var notes: [WO_Note] = []
        if let notesData = data["notes"] as? [[String: Any]] {
            for noteData in notesData {
                let note = try decodeWONoteFromFirestore(noteData)
                notes.append(note)
            }
        }
        
        return WorkOrder(
            id: id,
            createdBy: createdBy,
            customerId: customerId,
            customerName: customerName,
            customerCompany: customerCompany,
            customerEmail: customerEmail,
            customerTaxExempt: customerTaxExempt,
            customerPhone: customerPhone,
            customerEmojiTag: customerEmojiTag,
            workOrderType: workOrderType,
            primaryImageURL: primaryImageURL,
            timestamp: timestamp,
            status: status,
            workOrderNumber: workOrderNumber,
            flagged: flagged,
            assetTagId: assetTagId,
            estimatedCost: estimatedCost,
            finalCost: finalCost,
            dropdowns: dropdowns,
            dropdownSchemaVersion: dropdownSchemaVersion,
            lastModified: lastModified,
            lastModifiedBy: lastModifiedBy,
            tagBypassReason: tagBypassReason,
            isDeleted: isDeleted,
            syncStatus: syncStatus,
            lastSyncDate: lastSyncDate,
            notes: notes,
            items: items
        )
    }
    
    private func decodeWOItemFromFirestore(_ data: [String: Any]) throws -> WO_Item {
        let id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        let type = data["type"] as? String ?? ""
        let imageUrls = (data["imageUrls"] as? [String] ?? []).sorted { url1, url2 in
            // Sort by timestamp in filename to maintain upload order
            return extractTimestampFromURL(url1) < extractTimestampFromURL(url2)
        }
        let thumbUrls = (data["thumbUrls"] as? [String] ?? []).sorted { url1, url2 in
            // Sort by timestamp in filename to maintain upload order
            return extractTimestampFromURL(url1) < extractTimestampFromURL(url2)
        }
        let reasonsForService = data["reasonsForService"] as? [String] ?? []
        let completedReasons = data["completedReasons"] as? [String] ?? []
        let reasonNotes = data["reasonNotes"] as? String
        let assetTagId = data["assetTagId"] as? String
        let dropdowns = data["dropdowns"] as? [String: String] ?? [:]
        let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? Date()
        let lastModifiedBy = data["lastModifiedBy"] as? String
        
        // Decode status history
        var statusHistory: [WO_Status] = []
        if let statusHistoryData = data["statusHistory"] as? [[String: Any]] {
            for statusData in statusHistoryData {
                let status = statusData["status"] as? String ?? ""
                let user = statusData["user"] as? String ?? ""
                let timestamp = (statusData["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                let notes = statusData["notes"] as? String
                statusHistory.append(WO_Status(status: status, user: user, timestamp: timestamp, notes: notes))
            }
        }
        
        // Decode notes
        var notes: [WO_Note] = []
        if let notesData = data["notes"] as? [[String: Any]] {
            for noteData in notesData {
                let note = try decodeWONoteFromFirestore(noteData)
                notes.append(note)
            }
        }
        
        // Decode tag replacement history
        var tagReplacementHistory: [TagReplacement]?
        if let tagHistoryData = data["tagReplacementHistory"] as? [[String: Any]], !tagHistoryData.isEmpty {
            var replacements: [TagReplacement] = []
            for replacementData in tagHistoryData {
                let oldTagId = replacementData["oldTagId"] as? String ?? ""
                let newTagId = replacementData["newTagId"] as? String ?? ""
                let replacedBy = replacementData["replacedBy"] as? String ?? ""
                let timestamp = (replacementData["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                let reason = replacementData["reason"] as? String
                replacements.append(TagReplacement(oldTagId: oldTagId, newTagId: newTagId, replacedBy: replacedBy, timestamp: timestamp, reason: reason))
            }
            tagReplacementHistory = replacements
        }
        
        return WO_Item(
            id: id,
            itemNumber: nil,
            assetTagId: assetTagId,
            type: type,
            imageUrls: imageUrls,
            thumbUrls: thumbUrls,
            localImages: [],
            dropdowns: dropdowns,
            dropdownSchemaVersion: 1,
            reasonsForService: reasonsForService,
            reasonNotes: reasonNotes,
            completedReasons: completedReasons,
            statusHistory: statusHistory,
            notes: notes,
            testResult: nil,
            partsUsed: nil,
            hoursWorked: nil,
            estimatedCost: nil,
            finalCost: nil,
            assignedTo: "",
            isFlagged: false,
            tagReplacementHistory: tagReplacementHistory,
            lastModified: lastModified,
            lastModifiedBy: lastModifiedBy
        )
    }
    
    private func decodeWONoteFromFirestore(_ data: [String: Any]) throws -> WO_Note {
        let workOrderId = data["workOrderId"] as? String ?? ""
        let itemId = data["itemId"] as? String
        let user = data["user"] as? String ?? ""
        let text = data["text"] as? String ?? ""
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let imageUrls = data["imageUrls"] as? [String] ?? []
        
        return WO_Note(workOrderId: workOrderId, itemId: itemId, user: user, text: text, timestamp: timestamp, imageUrls: imageUrls)
    }
    
    /// Extract timestamp from Firebase Storage URL for sorting
    private func extractTimestampFromURL(_ url: String) -> String {
        // Extract filename from URL and get the timestamp part
        // URL format: .../workOrders/.../items/.../images/YYYYMMDD_HHMMSS_SSS.jpg
        if let lastSlash = url.lastIndex(of: "/") {
            let filename = String(url[url.index(after: lastSlash)...])
            // Remove .jpg extension and return the timestamp part
            if let dotIndex = filename.lastIndex(of: ".") {
                return String(filename[..<dotIndex])
            }
        }
        // Fallback: return the full URL if we can't extract timestamp
        return url
    }
}
