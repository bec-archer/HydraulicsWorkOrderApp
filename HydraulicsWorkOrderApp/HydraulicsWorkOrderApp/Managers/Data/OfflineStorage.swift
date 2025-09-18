//
//  OfflineStorage.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//

import Foundation
import CoreData

class OfflineStorage {
    static let shared = OfflineStorage()
    
    private init() {
        loadPersistentStore()
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        // Disable OfflineStorage to prevent CoreData conflicts
        // This prevents the "Failed to load model named OfflineWorkOrders" errors
        let container = NSPersistentContainer(name: "OfflineWorkOrders")
        // Don't load persistent stores to avoid conflicts
        return container
    }()
    
    private func loadPersistentStore() {
        // Persistent store is now loaded in the lazy container initialization
        // This method is kept for compatibility but does nothing
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                #if DEBUG
                print("❌ CoreData: Failed to save context: \(error.localizedDescription)")
                #endif
            }
        }
    }
    
    // MARK: - Work Order Operations
    
    func cacheWorkOrder(_ workOrder: WorkOrder) {
        let context = persistentContainer.viewContext
        
        // Check if work order already exists
        let fetchRequest: NSFetchRequest<CachedWorkOrder> = CachedWorkOrder.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "woNumber == %@", workOrder.workOrderNumber)
        
        do {
            let results = try context.fetch(fetchRequest)
            let cached = results.first ?? CachedWorkOrder(context: context)
            
            // Update or create cache entry
            cached.woNumber = workOrder.workOrderNumber
            cached.id = workOrder.id
            cached.lastModified = Date()
            cached.data = try? JSONEncoder().encode(workOrder)
            
            try context.save()
            
            #if DEBUG
            print("✅ CoreData: Cached WorkOrder \(workOrder.workOrderNumber)")
            #endif
        } catch {
            #if DEBUG
            print("❌ CoreData: Failed to cache WorkOrder: \(error.localizedDescription)")
            #endif
        }
    }
    
    func getCachedWorkOrder(woNumber: String) -> WorkOrder? {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CachedWorkOrder> = CachedWorkOrder.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "woNumber == %@", woNumber)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let cached = results.first,
               let data = cached.data,
               let workOrder = try? JSONDecoder().decode(WorkOrder.self, from: data) {
                return workOrder
            }
        } catch {
            #if DEBUG
            print("❌ CoreData: Failed to fetch cached WorkOrder: \(error.localizedDescription)")
            #endif
        }
        
        return nil
    }
    
    func clearCache() {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CachedWorkOrder.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            #if DEBUG
            print("✅ CoreData: Cache cleared successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ CoreData: Failed to clear cache: \(error.localizedDescription)")
            #endif
        }
    }
}
