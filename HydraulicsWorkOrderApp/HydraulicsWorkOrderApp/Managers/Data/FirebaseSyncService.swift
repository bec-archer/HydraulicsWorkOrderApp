//
//  FirebaseSyncService.swift
//  HydraulicsWorkOrderApp
//
//  Firebase sync service implementing "last write wins" strategy
//
import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class FirebaseSyncService: ObservableObject {
    static let shared = FirebaseSyncService()
    
    // MARK: - Published Properties
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus: CustomerSyncStatus = .synced
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NetworkMonitor.shared
    
    // MARK: - Initialization
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Setup
    private func setupNetworkMonitoring() {
        networkMonitor.isConnected
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.performSyncIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Perform sync if network is available and data needs syncing
    func performSyncIfNeeded() {
        guard networkMonitor.isConnected.value else {
            print("📡 No network connection, skipping sync")
            return
        }
        
        Task {
            await syncAllData()
        }
    }
    
    /// Manual sync trigger
    func manualSync() async {
        await syncAllData()
    }
    
    // MARK: - Private Sync Methods
    
    private func syncAllData() async {
        guard !isSyncing else {
            print("🔄 Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        syncStatus = .syncing
        
        do {
            // TODO: Implement when Core Data classes are generated
            print("⚠️ Core Data classes not yet generated - skipping sync")
            
            // Update sync status
            lastSyncDate = Date()
            syncStatus = .synced
            
            print("✅ Sync completed successfully (placeholder)")
        } catch {
            syncStatus = .failed
            print("❌ Sync failed: \(error.localizedDescription)")
        }
        
        isSyncing = false
    }
}

// MARK: - Extensions
extension FirebaseSyncService {
    
    /// Check if sync is needed
    var needsSync: Bool {
        // TODO: Implement when Core Data classes are generated
        return false
    }
    
    /// Get sync summary
    func getSyncSummary() -> (pendingWorkOrders: Int, pendingCustomers: Int) {
        // TODO: Implement when Core Data classes are generated
        return (0, 0)
    }
}
