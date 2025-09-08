//
//  WorkOrdersDatabase.swift
//  HydraulicsWorkOrderApp
//
//  Minimal placeholder - will be replaced with Core Data implementation
//
import Foundation
import SwiftUI

@MainActor
final class WorkOrdersDatabase: ObservableObject {
    static let shared = WorkOrdersDatabase()
    
    @Published var workOrders: [WorkOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Minimal Placeholder Methods
    
    func addWorkOrder(_ workOrder: WorkOrder) async throws {
        workOrders.append(workOrder)
    }
    
    func updateWorkOrder(_ workOrder: WorkOrder) async throws {
        if let index = workOrders.firstIndex(where: { $0.id == workOrder.id }) {
            workOrders[index] = workOrder
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
    
    func getAllWorkOrders() async throws -> [WorkOrder] {
        return workOrders
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
}
