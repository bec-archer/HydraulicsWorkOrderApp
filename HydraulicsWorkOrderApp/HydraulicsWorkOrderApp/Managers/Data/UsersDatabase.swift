//
//  UsersDatabase.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//

// ───── USERS DATABASE (Firestore + Offline) ─────
import Foundation
import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift

/// Handles Firestore read/write logic for Users with offline support
/// Mirrors WorkOrdersDatabase patterns for consistency
final class UsersDatabase: ObservableObject {
    static let shared = UsersDatabase()

    private let collectionName = "users"
    private let db = Firestore.firestore()

    @Published private(set) var users: [User] = []
    private var offlineQueue: [UserChange] = []
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Subscribe to connectivity changes for offline sync
        NotificationCenter.default
            .publisher(for: .connectivityStatusChanged)
            .sink { [weak self] _ in
                if NetworkMonitor.shared.isConnected {
                    self?.syncOfflineChanges()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Models

    /// Represents a pending user change for offline sync
    private struct UserChange {
        let type: ChangeType
        let user: User
        let timestamp: Date
    }

    // MARK: - Public Methods

    /// Load users from Firestore on appear (with offline fallback)
    func loadInitial() {
        // If we have cached users, use them immediately for UI responsiveness
        if !users.isEmpty {
            // Still try to fetch fresh data in background
            fetchAllUsers { _ in }
            return
        }
        
        fetchAllUsers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    self?.users = users
                case .failure(let error):
                    print("⚠️ Users load failed, using cached data: \(error.localizedDescription)")
                    // Load sample data if offline and no cache
                    if self?.users.isEmpty == true && !NetworkMonitor.shared.isConnected {
                        self?.loadSampleData()
                    }
                }
            }
        }
    }

    /// Fetch all users from Firestore (with offline fallback)
    func fetchAllUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        // If offline, return cached users
        if !NetworkMonitor.shared.isConnected {
            #if DEBUG
            print("📱 Offline mode: Returning cached users (\(self.users.count) items)")
            #endif
            completion(.success(self.users))
            return
        }

        db.collection(collectionName)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    // If Firestore fails, fall back to cached data
                    #if DEBUG
                    print("⚠️ Firestore fetch failed, using cached data: \(error.localizedDescription)")
                    #endif
                    completion(.success(self?.users ?? []))
                    return
                }

                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { [weak self] in
                        self?.users = []
                    }
                    completion(.success([]))
                    return
                }

                var decoded: [User] = []
                var failures: [(id: String, message: String)] = []

                for doc in docs {
                    do {
                        var user = try doc.data(as: User.self)
                        // Manually set @DocumentID if it's missing
                        if user.id.isEmpty {
                            user = User(
                                id: doc.documentID,
                                displayName: user.displayName,
                                phoneE164: user.phoneE164,
                                role: user.role,
                                isActive: user.isActive,
                                createdAt: user.createdAt,
                                updatedAt: user.updatedAt,
                                createdByUserId: user.createdByUserId,
                                updatedByUserId: user.updatedByUserId
                            )
                        }
                        decoded.append(user)
                        #if DEBUG
                        print("✅ Successfully decoded User: \(user.displayName) (ID: \(user.id))")
                        #endif
                    } catch {
                        let msg = "User decode failed for \(doc.documentID): \(error.localizedDescription)"
                        print("⚠️ User decode skipped:", msg)
                        failures.append((doc.documentID, msg))
                    }
                }

                // Log any decode failures
                if !failures.isEmpty {
                    print("⚠️ \(failures.count) users failed to decode:")
                    for failure in failures {
                        print("  - \(failure.id): \(failure.message)")
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    self?.users = decoded
                }
                completion(.success(decoded))
            }
    }

    /// Create a new user in Firestore (with offline queueing)
    func create(_ user: User) {
        // Add to local cache immediately for UI responsiveness
        DispatchQueue.main.async { [weak self] in
            self?.users.append(user)
        }

        // If offline, queue for later sync
        if !NetworkMonitor.shared.isConnected {
            queueOfflineChange(.create, user: user)
            return
        }

        // Create in Firestore
        createInFirestore(user)
    }

    /// Update an existing user in Firestore (with offline queueing)
    func update(_ user: User) {
        // Update local cache immediately for UI responsiveness
        DispatchQueue.main.async { [weak self] in
            if let index = self?.users.firstIndex(where: { $0.id == user.id }) {
                self?.users[index] = user
            }
        }

        // If offline, queue for later sync
        if !NetworkMonitor.shared.isConnected {
            queueOfflineChange(.update, user: user)
            return
        }

        // Update in Firestore
        updateInFirestore(user)
    }

    // MARK: - Private Firestore Methods

    private func createInFirestore(_ user: User) {
        do {
            // Prepare user for write (server-side timestamps)
            var userForWrite = user
            let now = Date()
            userForWrite.createdAt = now
            userForWrite.updatedAt = now

            // Skip nil values in serialization
            var docRef: DocumentReference?
            docRef = try db.collection(collectionName).addDocument(from: userForWrite) { [weak self] error in
                if let error = error {
                    print("❌ User creation failed: \(error.localizedDescription)")
                    // Remove from local cache on failure
                    DispatchQueue.main.async { [weak self] in
                        self?.users.removeAll { $0.id == user.id }
                    }
                    return
                }

                // Success: update local cache with Firestore documentID
                guard let docRef = docRef else { return }
                
                DispatchQueue.main.async { [weak self] in
                    let updatedUser = User(
                        id: docRef.documentID,
                        displayName: userForWrite.displayName,
                        phoneE164: userForWrite.phoneE164,
                        role: userForWrite.role,
                        isActive: userForWrite.isActive,
                        createdAt: userForWrite.createdAt,
                        updatedAt: userForWrite.updatedAt,
                        createdByUserId: userForWrite.createdByUserId,
                        updatedByUserId: userForWrite.updatedByUserId
                    )
                    if let index = self?.users.firstIndex(where: { $0.id == user.id }) {
                        self?.users[index] = updatedUser
                    }
                    #if DEBUG
                    print("✅ User created successfully: \(updatedUser.displayName) with ID: \(docRef.documentID)")
                    #endif
                }
            }
        } catch {
            print("❌ User creation encoding failed: \(error.localizedDescription)")
            // Remove from local cache on failure
            DispatchQueue.main.async { [weak self] in
                self?.users.removeAll { $0.id == user.id }
            }
        }
    }

    private func updateInFirestore(_ user: User) {
        do {
            // Prepare user for write (server-side timestamp)
            var userForWrite = user
            userForWrite.updatedAt = Date()

            // Skip nil values in serialization
            try db.collection(collectionName).document(user.id).setData(from: userForWrite) { [weak self] error in
                if let error = error {
                    print("❌ User update failed: \(error.localizedDescription)")
                    // Revert local cache on failure
                    DispatchQueue.main.async { [weak self] in
                        self?.fetchAllUsers { _ in } // Refresh from server
                    }
                    return
                }

                #if DEBUG
                print("✅ User updated successfully: \(user.displayName)")
                #endif
            }
        } catch {
            print("❌ User update encoding failed: \(error.localizedDescription)")
            // Revert local cache on failure
            fetchAllUsers { _ in } // Refresh from server
        }
    }

    // MARK: - Offline Queue Management

    private func queueOfflineChange(_ type: ChangeType, user: User) {
        let change = UserChange(type: type, user: user, timestamp: Date())
        offlineQueue.append(change)
        
        #if DEBUG
        print("📱 Offline: Queued \(type.rawValue) for user \(user.displayName)")
        print("📱 Offline queue size: \(offlineQueue.count)")
        #endif
    }

    /// Replay offline changes when connection is restored
    func syncOfflineChanges() {
        guard !offlineQueue.isEmpty else { return }
        
        #if DEBUG
        print("🔄 Syncing \(offlineQueue.count) offline changes...")
        #endif

        let changes = offlineQueue
        offlineQueue.removeAll()

        for change in changes {
            switch change.type {
            case .create:
                createInFirestore(change.user)
            case .update:
                updateInFirestore(change.user)
            case .delete:
                // TODO: Implement delete if needed
                break
            }
        }
    }

    /// Manual trigger for offline sync (useful for testing)
    func manualSyncOfflineChanges() {
        syncOfflineChanges()
    }

    // MARK: - Sample Data (Offline Fallback)

    /// Load sample users when offline and no cached data available
    private func loadSampleData() {
        let sampleUsers = [
            User(id: UUID().uuidString, displayName: "Chuck", phoneE164: "+12345550001", role: .manager, isActive: true, createdAt: .now, updatedAt: .now, createdByUserId: nil, updatedByUserId: nil),
            User(id: UUID().uuidString, displayName: "Joe", phoneE164: "+12345550002", role: .manager, isActive: true, createdAt: .now, updatedAt: .now, createdByUserId: nil, updatedByUserId: nil),
            User(id: UUID().uuidString, displayName: "Lee", phoneE164: "+12345550003", role: .manager, isActive: true, createdAt: .now, updatedAt: .now, createdByUserId: nil, updatedByUserId: nil)
        ]
        
        DispatchQueue.main.async { [weak self] in
            self?.users = sampleUsers
        }
        
        #if DEBUG
        print("📱 Offline: Loaded \(sampleUsers.count) sample users")
        #endif
    }

    // MARK: - Search (unchanged)

    /// Basic client-side search (works with cached data)
    func searchUsers(query: String) -> [User] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return users }
        return users.filter { u in
            u.displayName.lowercased().contains(q)
            || (u.phoneE164 ?? "").lowercased().contains(q)
            || u.role.rawValue.lowercased().contains(q)
        }
    }
}
// END
