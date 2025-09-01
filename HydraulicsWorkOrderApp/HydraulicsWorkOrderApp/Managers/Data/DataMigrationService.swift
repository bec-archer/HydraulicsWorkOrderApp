import Foundation
import FirebaseFirestore
import FirebaseStorage

/// Service to handle data migration and database cleanup
class DataMigrationService: ObservableObject {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus: String = ""
    @Published var isMigrating = false
    @Published var shouldDeleteImages: Bool = true
    
    /// Migrates all existing work orders to standardized format, then clears the database
    func migrateAndClearDatabase() async {
        await MainActor.run {
            self.isMigrating = true
            self.migrationStatus = "Starting migration..."
            self.migrationProgress = 0.0
        }
        
        do {
            // Step 1: Fetch all existing work orders
            await updateStatus("Fetching existing work orders...")
            let existingWorkOrders = try await fetchAllWorkOrders()
            
            // Step 2: Standardize the data format (for reference only)
            await updateStatus("Standardizing data format...")
            _ = standardizeWorkOrders(existingWorkOrders)
            
            // Step 3: Clear the database
            await updateStatus("Clearing database...")
            try await clearDatabase()
            
            // Step 4: Optionally, re-upload standardized data (if needed)
            // For now, we'll just clear everything since it's test data
            
            await MainActor.run {
                self.migrationStatus = "Migration completed successfully!"
                self.migrationProgress = 1.0
                self.isMigrating = false
            }
            
        } catch {
            await MainActor.run {
                self.migrationStatus = "Migration failed: \(error.localizedDescription)"
                self.isMigrating = false
            }
        }
    }
    
    /// Fetches all existing work orders from Firestore
    private func fetchAllWorkOrders() async throws -> [WorkOrder] {
        let snapshot = try await db.collection("workOrders").getDocuments()
        var workOrders: [WorkOrder] = []
        
        for document in snapshot.documents {
            do {
                let workOrder = try document.data(as: WorkOrder.self)
                workOrders.append(workOrder)
            } catch {
                // Try to decode using the legacy format
                let rawData = document.data()
                if let workOrder = buildWorkOrderFromRaw(rawData, id: document.documentID) {
                    workOrders.append(workOrder)
                }
            }
        }
        
        return workOrders
    }
    
    /// Standardizes work order data to consistent format
    private func standardizeWorkOrders(_ workOrders: [WorkOrder]) -> [WorkOrder] {
        return workOrders.map { workOrder in
            var standardizedWorkOrder = workOrder
            
            // Standardize items
            standardizedWorkOrder.items = workOrder.items.map { item in
                var standardizedItem = item
                
                // Ensure type is not empty or "Unknown"
                if standardizedItem.type.isEmpty || standardizedItem.type == "Unknown" {
                    standardizedItem.type = "Cylinder" // Default type
                }
                
                // Ensure imageUrls contains data (use thumbUrls if imageUrls is empty)
                if standardizedItem.imageUrls.isEmpty && !standardizedItem.thumbUrls.isEmpty {
                    standardizedItem.imageUrls = standardizedItem.thumbUrls
                }
                
                // Ensure all required fields have default values
                if standardizedItem.assignedTo.isEmpty {
                    standardizedItem.assignedTo = "Unassigned"
                }
                
                return standardizedItem
            }
            
            return standardizedWorkOrder
        }
    }
    
    /// Clears all data from Firestore and Storage
    private func clearDatabase() async throws {
        // Step 1: Clear Firestore collections
        await updateStatus("Clearing Firestore documents...")
        let collections = ["workOrders", "customers"]
        
        for collectionName in collections {
            let snapshot = try await db.collection(collectionName).getDocuments()
            
            for document in snapshot.documents {
                try await document.reference.delete()
            }
        }
        
        // Step 2: Clear Firebase Storage images (if requested)
        if shouldDeleteImages {
            await updateStatus("Clearing Firebase Storage images...")
            try await clearStorageImages()
        } else {
            await updateStatus("Skipping image deletion (images will remain orphaned)...")
        }
    }
    
    /// Clears all images from Firebase Storage
    private func clearStorageImages() async throws {
        let storageRef = storage.reference()
        
        // List all files in the storage bucket
        let result = try await storageRef.listAll()
        
        // Delete all files
        for item in result.items {
            try await item.delete()
        }
        
        // Also delete any subdirectories (if they exist)
        for prefix in result.prefixes {
            let subResult = try await prefix.listAll()
            for item in subResult.items {
                try await item.delete()
            }
        }
    }
    
    /// Builds a work order from raw data (legacy format support)
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
        
        // Handle both array format (new) and dictionary format (legacy)
        if let arr = raw["items"] as? [[String: Any]] {
            for anyItem in arr {
                let itemId = (anyItem["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
                let tagId  = anyItem["tagId"] as? String
                var urls   = anyItem["imageUrls"] as? [String]
                             ?? anyItem["imageURLs"] as? [String]
                             ?? []
                let thumbUrls = anyItem["thumbUrls"] as? [String] ?? []
                let type   = anyItem["type"] as? String 
                             ?? anyItem["itemType"] as? String
                             ?? anyItem["Type"] as? String
                             ?? "Cylinder"
                
                // If imageUrls is empty but thumbUrls has data, use thumbUrls as imageUrls
                if urls.isEmpty && !thumbUrls.isEmpty {
                    urls = thumbUrls
                }
                
                let dd     = anyItem["dropdowns"] as? [String: String] ?? [:]
                let ddv    = anyItem["dropdownSchemaVersion"] as? Int ?? schemaVer
                let reasons = anyItem["reasonsForService"] as? [String] ?? []
                let reasonNotes = anyItem["reasonNotes"] as? String
                let completedReasons = anyItem["completedReasons"] as? [String] ?? []
                let assigned = anyItem["assignedTo"] as? String ?? "Unassigned"
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
                    woItemId: nil,
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
                
                var mutableItem = item
                mutableItem.notes = notes
                mutableItem.lastModified = lastModified
                mutableItem.lastModifiedBy = lastModifiedBy
                items.append(mutableItem)
            }
        } else if let itemsDict = raw["items"] as? [String: Any] {
            // Legacy format: items is a dictionary with integer-string keys
            let sortedKeys = itemsDict.keys.sorted { key1, key2 in
                if let int1 = Int(key1), let int2 = Int(key2) {
                    return int1 < int2
                }
                return key1 < key2
            }
            
            for key in sortedKeys {
                guard let anyItem = itemsDict[key] as? [String: Any] else { continue }
                
                let itemId = (anyItem["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
                let tagId  = anyItem["tagId"] as? String
                var urls   = anyItem["imageUrls"] as? [String]
                             ?? anyItem["imageURLs"] as? [String]
                             ?? []
                let thumbUrls = anyItem["thumbUrls"] as? [String] ?? []
                let type   = anyItem["type"] as? String 
                             ?? anyItem["itemType"] as? String
                             ?? anyItem["Type"] as? String
                             ?? "Cylinder"
                
                // If imageUrls is empty but thumbUrls has data, use thumbUrls as imageUrls
                if urls.isEmpty && !thumbUrls.isEmpty {
                    urls = thumbUrls
                }
                
                let dd     = anyItem["dropdowns"] as? [String: String] ?? [:]
                let ddv    = anyItem["dropdownSchemaVersion"] as? Int ?? schemaVer
                let reasons = anyItem["reasonsForService"] as? [String] ?? []
                let reasonNotes = anyItem["reasonNotes"] as? String
                let completedReasons = anyItem["completedReasons"] as? [String] ?? []
                let assigned = anyItem["assignedTo"] as? String ?? "Unassigned"
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
                    woItemId: nil,
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
                
                var mutableItem = item
                mutableItem.notes = notes
                mutableItem.lastModified = lastModified
                mutableItem.lastModifiedBy = lastModifiedBy
                items.append(mutableItem)
            }
        }

        return WorkOrder(
            id: id,
            createdBy: createdBy,
            customerId: custId,
            customerName: custName,
            customerCompany: nil,
            customerEmail: nil,
            customerTaxExempt: false,
            customerPhone: phone,
            WO_Type: woType,
            imageURL: imageURL,
            imageURLs: nil,
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
    }
    
    @MainActor
    private func updateStatus(_ status: String) {
        self.migrationStatus = status
    }
}
