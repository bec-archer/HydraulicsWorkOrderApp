//
//  OfflineDataModel.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/18/25.
//
// OfflineDataModel.swift

import Foundation
import CoreData

// MARK: - Core Data Model

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        // Use the existing OfflineWorkOrders model from the bundle
        container = NSPersistentContainer(name: "OfflineWorkOrders")
        
        container.loadPersistentStores { description, error in
            if let error = error {
                #if DEBUG
                print("❌ CoreData: Failed to load OfflineWorkOrders model: \(error.localizedDescription)")
                #endif
                // Don't fatal error - just log and continue
            } else {
                #if DEBUG
                print("✅ CoreData: Successfully loaded OfflineWorkOrders model")
                #endif
            }
        }
    }
}

// MARK: - Core Data Entity
class CachedWorkOrder: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var type: String?
    @NSManaged public var jsonData: Data?
    @NSManaged public var lastModified: Date?
    @NSManaged public var synced: Bool
    @NSManaged public var changeType: String?
}
