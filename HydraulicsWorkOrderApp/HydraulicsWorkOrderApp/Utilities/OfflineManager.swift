//
//  OfflineManager.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/18/25.
//

// OfflineManager.swift

import Foundation
import CoreData
import Combine
import SwiftUI
import FirebaseStorage
import FirebaseFirestore

enum ChangeType: String {
    case create
    case update
    case delete
}

class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    private var cancellables = Set<AnyCancellable>()
    @Published var syncStatus: String = "All changes synced"
    @Published var pendingChanges: Int = 0
    
    private init() {
        // Subscribe to connectivity changes
        NotificationCenter.default
            .publisher(for: .connectivityStatusChanged)
            .sink { [weak self] _ in
                if NetworkMonitor.shared.isConnected {
                    self?.syncIfPossible()
                }
            }
            .store(in: &cancellables)
        
        // Initial count of pending changes
        countPendingChanges()
    }
    
    // MARK: - Public methods
    
    // Cache a work order item for offline reference
    func cacheWorkOrderItem(_ item: WO_Item) {
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        context.perform {
            // Check if already exists
            let fetchRequest: NSFetchRequest<CachedWorkOrder> = NSFetchRequest(entityName: "CachedWorkOrder")
            fetchRequest.predicate = NSPredicate(format: "id == %@", item.id.uuidString)
            
            do {
                let results = try context.fetch(fetchRequest)
                
                if let existingItem = results.first {
                    // Update existing
                    existingItem.type = item.type
                    existingItem.jsonData = self.encode(item)
                    existingItem.lastModified = Date()
                    existingItem.synced = true
                } else {
                    // Create new
                    let cachedItem = CachedWorkOrder(context: context)
                    cachedItem.id = item.id.uuidString
                    cachedItem.type = item.type
                    cachedItem.jsonData = self.encode(item)
                    cachedItem.lastModified = Date()
                    cachedItem.synced = true
                }
                
                try context.save()
            } catch {
                print("Error caching work order: \(error)")
            }
        }
    }
    
    // Save work order changes when offline
    func saveWorkOrderChange(_ item: WO_Item, changeType: ChangeType) {
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        context.perform {
            // Check if already exists
            let fetchRequest: NSFetchRequest<CachedWorkOrder> = NSFetchRequest(entityName: "CachedWorkOrder")
            fetchRequest.predicate = NSPredicate(format: "id == %@", item.id.uuidString)
            
            do {
                let results = try context.fetch(fetchRequest)
                
                if let existingItem = results.first {
                    // Update existing
                    existingItem.type = item.type
                    existingItem.jsonData = self.encode(item)
                    existingItem.lastModified = Date()
                    existingItem.synced = false
                    existingItem.changeType = changeType.rawValue
                } else {
                    // Create new
                    let cachedItem = CachedWorkOrder(context: context)
                    cachedItem.id = item.id.uuidString
                    cachedItem.type = item.type
                    cachedItem.jsonData = self.encode(item)
                    cachedItem.lastModified = Date()
                    cachedItem.synced = false
                    cachedItem.changeType = changeType.rawValue
                }
                
                try context.save()
                
                DispatchQueue.main.async {
                    self.pendingChanges += 1
                    self.syncStatus = "Changes pending sync"
                }
            } catch {
                print("Error saving offline work order: \(error)")
            }
        }
    }
    
    // Add note to work order while offline
    func addNoteOffline(to item: WO_Item, note: WO_Note) {
        var updatedItem = item
        updatedItem.notes.append(note)
        saveWorkOrderChange(updatedItem, changeType: .update)
    }
    
    // Change status while offline
    @MainActor func changeStatusOffline(for item: WO_Item, newStatus: String) {
        var updatedItem = item
        let user = AppState.shared.currentUserName
        let statusEntry = WO_Status(status: newStatus, user: user, timestamp: Date())
        updatedItem.statusHistory.append(statusEntry)
        saveWorkOrderChange(updatedItem, changeType: .update)
    }
    
    // Create a new work order while offline
    func createWorkOrderOffline(_ item: WO_Item) {
        saveWorkOrderChange(item, changeType: .create)
    }
    
    // Manually trigger sync
    func syncNow() {
        syncIfPossible()
    }
    
    // Get a cached work order by ID
    func getCachedWorkOrder(id: UUID) -> WO_Item? {
        let context = PersistenceController.shared.container.viewContext
        
        let fetchRequest: NSFetchRequest<CachedWorkOrder> = NSFetchRequest(entityName: "CachedWorkOrder")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id.uuidString)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let cachedItem = results.first, let data = cachedItem.jsonData {
                return decode(data)
            }
        } catch {
            print("Error fetching cached work order: \(error)")
        }
        
        return nil
    }
    
    // Get all cached work orders
    func getAllCachedWorkOrders() -> [WO_Item] {
        let context = PersistenceController.shared.container.viewContext
        
        let fetchRequest: NSFetchRequest<CachedWorkOrder> = NSFetchRequest(entityName: "CachedWorkOrder")
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.compactMap { cached -> WO_Item? in
                guard let data = cached.jsonData else { return nil }
                return decode(data)
            }
        } catch {
            print("Error fetching all cached work orders: \(error)")
        }
        
        return []
    }
    
    // MARK: - Private methods
    
    private func countPendingChanges() {
        let context = PersistenceController.shared.container.viewContext
        
        let fetchRequest: NSFetchRequest<CachedWorkOrder> = NSFetchRequest(entityName: "CachedWorkOrder")
        fetchRequest.predicate = NSPredicate(format: "synced == %@", NSNumber(value: false))
        
        do {
            let results = try context.fetch(fetchRequest)
            DispatchQueue.main.async {
                self.pendingChanges = results.count
                self.syncStatus = results.isEmpty ? "All changes synced" : "Changes pending sync"
            }
        } catch {
            print("Error counting pending changes: \(error)")
        }
    }
    
    private func syncIfPossible() {
        guard NetworkMonitor.shared.isConnected else {
            return
        }
        
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        context.perform {
            let fetchRequest: NSFetchRequest<CachedWorkOrder> = NSFetchRequest(entityName: "CachedWorkOrder")
            fetchRequest.predicate = NSPredicate(format: "synced == %@", NSNumber(value: false))
            
            do {
                let results = try context.fetch(fetchRequest)
                
                for cachedItem in results {
                    guard let jsonData = cachedItem.jsonData,
                          let item = self.decode(jsonData),
                          let changeTypeString = cachedItem.changeType,
                          let changeType = ChangeType(rawValue: changeTypeString) else {
                        continue
                    }
                    
                    switch changeType {
                    case .create:
                        self.uploadNewWorkOrder(item) { success in
                            if success {
                                self.markAsSynced(cachedItem.id)
                            }
                        }
                    case .update:
                        self.updateWorkOrder(item) { success in
                            if success {
                                self.markAsSynced(cachedItem.id)
                            }
                        }
                    case .delete:
                        self.deleteWorkOrder(item.id) { success in
                            if success {
                                self.markAsSynced(cachedItem.id)
                            }
                        }
                    }
                }
            } catch {
                print("Error syncing changes: \(error)")
            }
        }
    }
    
    private func markAsSynced(_ itemId: String) {
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        context.perform {
            let fetchRequest: NSFetchRequest<CachedWorkOrder> = NSFetchRequest(entityName: "CachedWorkOrder")
            fetchRequest.predicate = NSPredicate(format: "id == %@", itemId)
            
            do {
                let results = try context.fetch(fetchRequest)
                
                if let item = results.first {
                    item.synced = true
                    try context.save()
                    
                    DispatchQueue.main.async {
                        self.pendingChanges -= 1
                        if self.pendingChanges <= 0 {
                            self.syncStatus = "All changes synced"
                        }
                    }
                }
            } catch {
                print("Error marking item as synced: \(error)")
            }
        }
    }
    
    // MARK: - Data conversion helpers
    
    private func encode(_ item: WO_Item) -> Data? {
        try? JSONEncoder().encode(item)
    }
    
    private func decode(_ data: Data) -> WO_Item? {
        try? JSONDecoder().decode(WO_Item.self, from: data)
    }
    
    // MARK: - Firebase sync methods
    
    private func uploadNewWorkOrder(_ item: WO_Item, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("workOrders").document(item.id.uuidString).setData([
            "type": item.type,
            "dropdowns": item.dropdowns,
            "notes": item.notes.map { try? JSONEncoder().encode($0) },
            "statusHistory": item.statusHistory.map { try? JSONEncoder().encode($0) },
            "imageUrls": item.imageUrls,
            "thumbUrls": item.thumbUrls,
            "createdAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("Error creating document: \(error)")
                completion(false)
            } else {
                print("Document successfully created")
                completion(true)
            }
        }
    }
    
    private func updateWorkOrder(_ item: WO_Item, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("workOrders").document(item.id.uuidString).updateData([
            "type": item.type,
            "dropdowns": item.dropdowns,
            "notes": item.notes.map { try? JSONEncoder().encode($0) },
            "statusHistory": item.statusHistory.map { try? JSONEncoder().encode($0) },
            "imageUrls": item.imageUrls,
            "thumbUrls": item.thumbUrls,
            "updatedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("Error updating document: \(error)")
                completion(false)
            } else {
                print("Document successfully updated")
                completion(true)
            }
        }
    }
    
    private func deleteWorkOrder(_ itemId: UUID, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("workOrders").document(itemId.uuidString).delete() { error in
            if let error = error {
                print("Error removing document: \(error)")
                completion(false)
            } else {
                print("Document successfully removed")
                completion(true)
            }
        }
    }
}
