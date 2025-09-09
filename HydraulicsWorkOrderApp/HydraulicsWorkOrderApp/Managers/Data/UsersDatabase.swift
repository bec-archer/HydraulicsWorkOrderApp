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
    
    // Blacklist of user IDs that should be automatically deleted if recreated
    private var deletedUserBlacklist: Set<String> = []

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
        print("📱 loadInitial() called - users in cache: \(users.count)")
        
        // Always fetch fresh data to ensure we have the latest state and remove duplicates
        print("📱 Fetching fresh data from Firestore")
        fetchAllUsers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    print("📱 Fetched \(users.count) users from Firestore")
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
                        print("✅ Successfully decoded User: \(user.displayName) (ID: \(user.id)) - Active: \(user.isActive)")
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

                // Remove duplicates by ID before setting users
                // Prefer the most recent version (based on updatedAt)
                let uniqueUsers = Dictionary(grouping: decoded, by: { $0.id })
                    .compactMapValues { users in
                        users.max(by: { $0.updatedAt < $1.updatedAt })
                    }
                    .values
                    .sorted { $0.displayName < $1.displayName }
                
                // Filter out blacklisted users (users that were deleted and shouldn't be recreated)
                let filteredUsers = uniqueUsers.filter { [weak self] user in
                    guard let self = self else { return true }
                    if self.deletedUserBlacklist.contains(user.id) {
                        print("🚫 Blacklisted user detected and will be deleted: \(user.displayName) (ID: \(user.id))")
                        // Delete the blacklisted user from Firestore
                        DispatchQueue.main.async { [weak self] in
                            self?.deleteInFirestore(user)
                        }
                        return false
                    }
                    return true
                }
                
                print("📱 Fetched \(decoded.count) users, \(uniqueUsers.count) unique users, \(filteredUsers.count) after blacklist filter")
                if decoded.count != uniqueUsers.count {
                    print("⚠️ Found \(decoded.count - uniqueUsers.count) duplicate users in Firestore")
                    print("⚠️ This indicates duplicate documents in Firestore that need cleanup")
                    print("⚠️ Using most recent version for each user")
                    
                    // Clean up duplicate documents in Firestore
                    self?.cleanupDuplicateDocuments(decoded: decoded, uniqueUsers: Array(uniqueUsers))
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.users = Array(filteredUsers)
                }
                completion(.success(Array(filteredUsers)))
            }
    }

    /// Create a new user in Firestore (with offline queueing)
    func create(_ user: User) {
        print("👤 UsersDatabase.create() called for user: \(user.displayName) (ID: \(user.id))")
        print("👤 User isActive: \(user.isActive)")
        print("👤 Call stack: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n"))")
        
        // Add to local cache immediately for UI responsiveness
        DispatchQueue.main.async { [weak self] in
            self?.users.append(user)
        }

        // If offline, queue for later sync
        if !NetworkMonitor.shared.isConnected {
            print("👤 Offline mode: Queueing create for later sync")
            queueOfflineChange(.create, user: user)
            return
        }

        // Create in Firestore
        print("👤 Online mode: Creating in Firestore")
        createInFirestore(user)
    }

    /// Update an existing user in Firestore (with offline queueing)
    func update(_ user: User) {
        print("🔄 UsersDatabase.update() called for user: \(user.displayName) (ID: \(user.id))")
        print("🔄 User isActive: \(user.isActive)")
        print("🔄 Users in cache before update: \(users.count)")
        
        // Update local cache immediately for UI responsiveness
        DispatchQueue.main.async { [weak self] in
            if let index = self?.users.firstIndex(where: { $0.id == user.id }) {
                print("🔄 Updating existing user at index \(index)")
                self?.users[index] = user
            } else {
                print("⚠️ User not found in cache, adding new user")
                self?.users.append(user)
            }
            print("🔄 Users in cache after update: \(self?.users.count ?? 0)")
        }

        // If offline, queue for later sync
        if !NetworkMonitor.shared.isConnected {
            print("🔄 Offline mode: Queueing update for later sync")
            queueOfflineChange(.update, user: user)
            return
        }

        // Update in Firestore
        print("🔄 Online mode: Updating in Firestore")
        updateInFirestore(user)
    }

    /// Delete a user from Firestore (with offline queueing)
    func delete(_ user: User) {
        print("🗑️ UsersDatabase.delete() called for user: \(user.displayName) (ID: \(user.id))")
        print("🗑️ Network connected: \(NetworkMonitor.shared.isConnected)")
        print("🗑️ Users in cache before deletion: \(users.count)")
        
        // Remove from local cache immediately for UI responsiveness
        DispatchQueue.main.async { [weak self] in
            self?.users.removeAll { $0.id == user.id }
            print("🗑️ Users in cache after local removal: \(self?.users.count ?? 0)")
        }

        // If offline, queue for later sync
        if !NetworkMonitor.shared.isConnected {
            print("🗑️ Offline mode: Queueing delete for later sync")
            queueOfflineChange(.delete, user: user)
            return
        }

        // Add to blacklist to prevent external recreation
        deletedUserBlacklist.insert(user.id)
        print("🗑️ Added user to blacklist: \(user.id)")
        
        // Actually delete from Firestore to prevent external recreation
        print("🗑️ Online mode: Permanently deleting from Firestore")
        deleteInFirestore(user)
    }

    // MARK: - Private Firestore Methods

    private func createInFirestore(_ user: User) {
        print("👤 createInFirestore() called for user: \(user.displayName) (ID: \(user.id))")
        print("👤 User isActive: \(user.isActive)")
        
        do {
            // Prepare user for write (server-side timestamps)
            var userForWrite = user
            let now = Date()
            userForWrite.createdAt = now
            userForWrite.updatedAt = now

            print("👤 Creating document in Firestore collection: \(collectionName)")
            // Skip nil values in serialization
            var docRef: DocumentReference?
            docRef = try db.collection(collectionName).addDocument(from: userForWrite) { [weak self] error in
                if let error = error {
                    print("❌ User creation failed: \(error.localizedDescription)")
                    print("❌ Error details: \(error)")
                    // Remove from local cache on failure
                    DispatchQueue.main.async { [weak self] in
                        self?.users.removeAll { $0.id == user.id }
                    }
                    return
                }

                print("✅ User created successfully in Firestore: \(user.displayName)")
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
        print("🔄 updateInFirestore() called for user: \(user.displayName) (ID: \(user.id))")
        print("🔄 User isActive: \(user.isActive)")
        print("🔄 User PIN: \(user.pin ?? "none")")
        
        do {
            // Prepare user for write (server-side timestamp)
            var userForWrite = user
            userForWrite.updatedAt = Date()

            print("🔄 Updating Firestore document: \(user.id)")
            // Use setData with merge to handle cases where document might not exist
            try db.collection(collectionName).document(user.id).setData(from: userForWrite, merge: true) { [weak self] error in
                if let error = error {
                    print("❌ User update failed: \(error.localizedDescription)")
                    print("❌ Error details: \(error)")
                    
                    // Revert local cache on failure
                    DispatchQueue.main.async { [weak self] in
                        self?.fetchAllUsers { _ in } // Refresh from server
                    }
                    return
                }

                print("✅ User updated successfully in Firestore: \(user.displayName)")
                print("✅ Document \(user.id) updated with isActive: \(user.isActive)")
            }
        } catch {
            print("❌ User update encoding failed: \(error.localizedDescription)")
            print("❌ Encoding error details: \(error)")
            // Revert local cache on failure
            fetchAllUsers { _ in } // Refresh from server
        }
    }

    private func deleteInFirestore(_ user: User) {
        print("🗑️ deleteInFirestore() called for user: \(user.displayName) (ID: \(user.id))")
        print("🗑️ Collection: \(collectionName), Document ID: \(user.id)")
        print("🗑️ Network status: \(NetworkMonitor.shared.isConnected ? "Connected" : "Offline")")
        
        // Check if document exists first
        db.collection(collectionName).document(user.id).getDocument { [weak self] document, error in
            if let error = error {
                print("❌ Error checking if document exists: \(error.localizedDescription)")
                // Re-add to local cache on failure
                DispatchQueue.main.async { [weak self] in
                    self?.users.append(user)
                    print("🗑️ Re-added user to cache after document check failure")
                }
                return
            }
            
            if let document = document, document.exists {
                print("🗑️ Document exists, proceeding with deletion")
            } else {
                print("⚠️ Document does not exist in Firestore, but was in local cache")
                // Don't re-add to cache since it doesn't exist in Firestore
                return
            }
            
            // Proceed with deletion
            self?.db.collection(self?.collectionName ?? "users").document(user.id).delete { [weak self] error in
                if let error = error {
                    print("❌ User deletion failed: \(error.localizedDescription)")
                    print("❌ Error details: \(error)")
                    print("❌ Error code: \(error._code)")
                    print("❌ Error domain: \(error._domain)")
                    // Re-add to local cache on failure
                    DispatchQueue.main.async { [weak self] in
                        self?.users.append(user)
                        print("🗑️ Re-added user to cache after deletion failure")
                    }
                    return
                }

                print("✅ User deleted successfully from Firestore: \(user.displayName)")
                print("✅ Document \(user.id) removed from collection \(self?.collectionName ?? "unknown")")
                
                // Verify deletion by checking if document still exists
                self?.db.collection(self?.collectionName ?? "users").document(user.id).getDocument { document, error in
                    if let error = error {
                        print("⚠️ Error verifying deletion: \(error.localizedDescription)")
                    } else if let document = document, document.exists {
                        print("❌ VERIFICATION FAILED: Document still exists after deletion!")
                    } else {
                        print("✅ VERIFICATION SUCCESS: Document confirmed deleted")
                    }
                }
            }
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

        // Group changes by user ID to prevent duplicate operations
        let changesByUser = Dictionary(grouping: changes) { $0.user.id }
        
        for (_, userChanges) in changesByUser {
            // Only process the most recent change for each user
            guard let latestChange = userChanges.max(by: { $0.timestamp < $1.timestamp }) else { continue }
            
            print("🔄 Syncing latest change: \(latestChange.type) for user: \(latestChange.user.displayName)")
            switch latestChange.type {
            case .create:
                createInFirestore(latestChange.user)
            case .update:
                updateInFirestore(latestChange.user)
            case .delete:
                print("🔄 Syncing delete for user: \(latestChange.user.displayName)")
                deleteInFirestore(latestChange.user)
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

    // MARK: - Authentication

    /// Authenticate user by PIN (checks custom PIN first, then default role-based PIN)
    func authenticateUser(pin: String, completion: @escaping (Result<User?, Error>) -> Void) {
        // If users haven't been loaded yet, load them first
        if users.isEmpty {
            fetchAllUsers { [weak self] result in
                switch result {
                case .success:
                    // Users loaded, now try authentication
                    self?.performAuthentication(pin: pin, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            // Users already loaded, perform authentication
            performAuthentication(pin: pin, completion: completion)
        }
    }
    
    /// Internal method to perform the actual authentication logic
    private func performAuthentication(pin: String, completion: @escaping (Result<User?, Error>) -> Void) {
        #if DEBUG
        print("🔐 Authenticating PIN: \(pin)")
        print("🔐 Available users: \(users.count)")
        for user in users {
            print("  - \(user.displayName) (\(user.role.rawValue)) - Active: \(user.isActive) - PIN: \(user.pin ?? "none")")
        }
        #endif
        
        // First, try to find user with custom PIN
        if let userWithCustomPin = users.first(where: { $0.pin == pin && $0.isActive }) {
            #if DEBUG
            print("🔐 Found user with custom PIN: \(userWithCustomPin.displayName)")
            #endif
            completion(.success(userWithCustomPin))
            return
        }
        
        // If no custom PIN matches, try default role-based PINs
        let defaultPins: [UserRole: String] = [
            .tech: "1234",
            .manager: "2345", 
            .admin: "5678",
            .superadmin: "0000"
        ]
        
        for (role, defaultPin) in defaultPins {
            if pin == defaultPin {
                // Find first active user with this role and no custom PIN
                if let userWithDefaultPin = users.first(where: { 
                    $0.role == role && 
                    $0.isActive && 
                    ($0.pin == nil || $0.pin?.isEmpty == true)
                }) {
                    #if DEBUG
                    print("🔐 Found user with default PIN for role \(role.rawValue): \(userWithDefaultPin.displayName)")
                    #endif
                    completion(.success(userWithDefaultPin))
                    return
                }
            }
        }
        
        #if DEBUG
        print("🔐 No user found with PIN: \(pin)")
        #endif
        
        // No user found with this PIN
        completion(.success(nil))
    }

    // MARK: - Duplicate Cleanup

    /// Clean up duplicate documents in Firestore by removing older versions
    private func cleanupDuplicateDocuments(decoded: [User], uniqueUsers: [User]) {
        print("🧹 Starting cleanup of duplicate documents in Firestore")
        
        // Group all users by ID to find duplicates
        let usersByID = Dictionary(grouping: decoded, by: { $0.id })
        
        for (userID, duplicateUsers) in usersByID {
            if duplicateUsers.count > 1 {
                print("🧹 Found \(duplicateUsers.count) duplicates for user ID: \(userID)")
                
                // Find the most recent version (the one we kept)
                guard let mostRecentUser = duplicateUsers.max(by: { $0.updatedAt < $1.updatedAt }) else { continue }
                
                // Delete all other versions
                let usersToDelete = duplicateUsers.filter { $0.id != mostRecentUser.id || $0.updatedAt != mostRecentUser.updatedAt }
                
                for userToDelete in usersToDelete {
                    print("🧹 Deleting duplicate document for user: \(userToDelete.displayName) (updated: \(userToDelete.updatedAt))")
                    
                    // Delete the duplicate document from Firestore
                    db.collection(collectionName).document(userToDelete.id).delete { error in
                        if let error = error {
                            print("❌ Failed to delete duplicate document: \(error.localizedDescription)")
                        } else {
                            print("✅ Successfully deleted duplicate document for: \(userToDelete.displayName)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search

    /// Basic client-side search (works with cached data)
    func searchUsers(query: String) -> [User] {
        // Show all users (active and inactive) so inactive users can be deleted
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
