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
        container = NSPersistentContainer(name: "OfflineWorkOrders")
        
        // Set up the schema
        let workOrderEntity = NSEntityDescription()
        workOrderEntity.name = "CachedWorkOrder"
        workOrderEntity.managedObjectClassName = NSStringFromClass(CachedWorkOrder.self)
        
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .stringAttributeType
        idAttribute.isOptional = false
        
        let typeAttribute = NSAttributeDescription()
        typeAttribute.name = "type"
        typeAttribute.attributeType = .stringAttributeType
        typeAttribute.isOptional = true
        
        let jsonDataAttribute = NSAttributeDescription()
        jsonDataAttribute.name = "jsonData"
        jsonDataAttribute.attributeType = .binaryDataAttributeType
        jsonDataAttribute.isOptional = true
        
        let lastModifiedAttribute = NSAttributeDescription()
        lastModifiedAttribute.name = "lastModified"
        lastModifiedAttribute.attributeType = .dateAttributeType
        lastModifiedAttribute.isOptional = true
        
        let syncedAttribute = NSAttributeDescription()
        syncedAttribute.name = "synced"
        syncedAttribute.attributeType = .booleanAttributeType
        syncedAttribute.isOptional = false
        
        let changeTypeAttribute = NSAttributeDescription()
        changeTypeAttribute.name = "changeType"
        changeTypeAttribute.attributeType = .stringAttributeType
        changeTypeAttribute.isOptional = true
        
        workOrderEntity.properties = [
            idAttribute,
            typeAttribute,
            jsonDataAttribute,
            lastModifiedAttribute,
            syncedAttribute,
            changeTypeAttribute
        ]
        
        let model = NSManagedObjectModel()
        model.entities = [workOrderEntity]
        
        let container = NSPersistentContainer(name: "WorkOrderModel", managedObjectModel: NSManagedObjectModel.mergedModel(from: [Bundle.main])!)
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
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
