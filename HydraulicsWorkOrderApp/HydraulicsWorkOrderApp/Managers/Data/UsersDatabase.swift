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
    private var deletedUserBlacklist: Set<String> = [] {
        didSet {
            // Persist the blacklist to UserDefaults
            UserDefaults.standard.set(Array(deletedUserBlacklist), forKey: "deletedUserBlacklist")
        }
    }

    private init() {
        // Load persisted blacklist from UserDefaults
        if let savedBlacklist = UserDefaults.standard.array(forKey: "deletedUserBlacklist") as? [String] {
            deletedUserBlacklist = Set(savedBlacklist)
            print("📱 Loaded \(deletedUserBlacklist.count) blacklisted user IDs from UserDefaults")
        }
        
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
        
        // If we already have users in cache, don't aggressively overwrite them
        // This prevents race conditions where local changes get overwritten by stale Firestore data
        if !users.isEmpty {
            print("📱 Users already in cache, doing background refresh instead of overwrite")
            // Do a background refresh but don't overwrite local cache immediately
            fetchAllUsers { [weak self] result in
                switch result {
                case .success(let firestoreUsers):
                    print("📱 Background refresh: Fetched \(firestoreUsers.count) users from Firestore")
                    // Only update if we got more recent data (based on updatedAt timestamps)
                    self?.mergeUsersFromFirestore(firestoreUsers)
                case .failure(let error):
                    print("⚠️ Background refresh failed: \(error.localizedDescription)")
                }
            }
        } else {
            // No users in cache, fetch fresh data
            print("📱 No users in cache, fetching fresh data from Firestore")
            fetchAllUsers { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let users):
                        print("📱 Fetched \(users.count) users from Firestore")
                        self?.users = users
                    case .failure(let error):
                        print("⚠️ Users load failed, using cached data: \(error.localizedDescription)")
                        // No sample data - users must be populated manually
                        print("📱 No users found - please populate users manually")
                    }
                }
            }
        }
    }
    
    /// Merge users from Firestore, preferring more recent data
    private func mergeUsersFromFirestore(_ firestoreUsers: [User]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var updatedUsers = self.users
            
            for firestoreUser in firestoreUsers {
                if let localIndex = updatedUsers.firstIndex(where: { $0.id == firestoreUser.id }) {
                    let localUser = updatedUsers[localIndex]
                    
                    // Only update if Firestore data is more recent
                    if firestoreUser.updatedAt > localUser.updatedAt {
                        print("📱 Updating user \(firestoreUser.displayName) with more recent Firestore data")
                        updatedUsers[localIndex] = firestoreUser
                    } else {
                        print("📱 Keeping local data for user \(localUser.displayName) (more recent)")
                    }
                } else {
                    // New user from Firestore
                    print("📱 Adding new user from Firestore: \(firestoreUser.displayName)")
                    updatedUsers.append(firestoreUser)
                }
            }
            
            self.users = updatedUsers
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
                        // Always use the Firestore document ID to ensure consistency
                        user = User(
                            id: doc.documentID,
                            displayName: user.displayName,
                            phoneE164: user.phoneE164,
                            role: user.role,
                            isActive: user.isActive,
                            pin: user.pin,  // CRITICAL: Don't lose the PIN!
                            createdAt: user.createdAt,
                            updatedAt: user.updatedAt,
                            createdByUserId: user.createdByUserId,
                            updatedByUserId: user.updatedByUserId
                        )
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
        
        // Validate that user exists and has a valid ID
        guard !user.id.isEmpty else {
            print("❌ ERROR: Cannot update user with empty ID")
            return
        }
        
        // Check if this is actually an update (user exists) or a create (user doesn't exist)
        let existingUser = users.first(where: { $0.id == user.id })
        if existingUser == nil {
            print("⚠️ WARNING: User with ID \(user.id) not found in cache")
            print("⚠️ This could be due to ID mismatch between local cache and Firestore")
            print("⚠️ User details: \(user.displayName), Phone: \(user.phoneE164 ?? "none")")
            
            // Try to find user by display name and phone as fallback
            if let fallbackUser = users.first(where: { 
                $0.displayName == user.displayName && $0.phoneE164 == user.phoneE164 
            }) {
                print("⚠️ Found matching user by name/phone with different ID: \(fallbackUser.id)")
                print("⚠️ This suggests the user was created with UUID but Firestore has different ID")
                print("⚠️ The update will proceed with the provided user ID")
            }
        }
        
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
                        pin: userForWrite.pin,
                        createdAt: userForWrite.createdAt,
                        updatedAt: userForWrite.updatedAt,
                        createdByUserId: userForWrite.createdByUserId,
                        updatedByUserId: userForWrite.updatedByUserId
                    )
                    // Remove the old user (with UUID) and add the new user (with Firestore ID)
                    self?.users.removeAll { $0.id == user.id }
                    self?.users.append(updatedUser)
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
        print("🔄 Network connected: \(NetworkMonitor.shared.isConnected)")
        print("🔄 Firestore collection: \(collectionName)")
        
        // Create a dictionary without the ID field to avoid conflicts
        let userData: [String: Any] = [
            "displayName": user.displayName,
            "phoneE164": user.phoneE164 as Any,
            "role": user.role.rawValue,
            "isActive": user.isActive,
            "pin": user.pin as Any,
            "createdAt": user.createdAt,
            "updatedAt": Date(),
            "createdByUserId": user.createdByUserId as Any,
            "updatedByUserId": user.updatedByUserId as Any
        ]

        print("🔄 Updating Firestore document: \(user.id)")
        print("🔄 User data being written:")
        print("  - Display Name: \(user.displayName)")
        print("  - Role: \(user.role.rawValue)")
        print("  - Is Active: \(user.isActive)")
        print("  - PIN: \(user.pin ?? "nil")")
        print("  - Updated At: \(Date())")
        
        // First check if the document exists
        db.collection(collectionName).document(user.id).getDocument { [weak self] document, error in
            if let error = error {
                print("❌ Error checking if document exists: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                print("✅ Document exists, proceeding with update")
                // Document exists, proceed with update
                self?.performFirestoreUpdate(user: user, userData: userData)
            } else {
                print("❌ Document does not exist with ID: \(user.id)")
                print("❌ This will create a duplicate user! Aborting update.")
                print("❌ User should be found by name/phone and updated with correct Firestore ID")
                
                // Try to find the user by name and phone to get the correct Firestore ID
                self?.findAndUpdateUserByDetails(user: user, userData: userData)
            }
        }
    }
    
    private func performFirestoreUpdate(user: User, userData: [String: Any]) {
        // Use setData with merge to update existing document
        db.collection(collectionName).document(user.id).setData(userData, merge: true) { [weak self] error in
            if let error = error {
                print("❌ User update failed: \(error.localizedDescription)")
                print("❌ Error details: \(error)")
                print("❌ Error code: \(error._code)")
                print("❌ Error domain: \(error._domain)")
                
                // Revert local cache on failure
                DispatchQueue.main.async { [weak self] in
                    self?.fetchAllUsers { _ in }
                }
                return
            }

            print("✅ User updated successfully in Firestore: \(user.displayName)")
            print("✅ Document \(user.id) updated with isActive: \(user.isActive)")
            print("✅ PIN updated to: \(user.pin ?? "nil")")
            
            // Verify the update by reading the document back
            self?.verifyFirestoreUpdate(user)
        }
    }
    
    private func findAndUpdateUserByDetails(user: User, userData: [String: Any]) {
        print("🔍 Searching for user by name and phone to find correct Firestore ID")
        
        // Search for user by display name and phone number
        db.collection(collectionName)
            .whereField("displayName", isEqualTo: user.displayName)
            .whereField("phoneE164", isEqualTo: user.phoneE164 as Any)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error searching for user: \(error.localizedDescription)")
                    return
                }
                
                guard let docs = snapshot?.documents, !docs.isEmpty else {
                    print("❌ No user found with matching name and phone")
                    print("❌ This suggests the user was never properly created in Firestore")
                    return
                }
                
                if docs.count > 1 {
                    print("⚠️ Found \(docs.count) users with matching name and phone - this indicates duplicates")
                }
                
                // Use the first (most recent) document
                let correctDoc = docs.first!
                let correctId = correctDoc.documentID
                print("✅ Found user with correct Firestore ID: \(correctId)")
                
                // Create a new user with the correct ID
                let correctedUser = User(
                    id: correctId,
                    displayName: user.displayName,
                    phoneE164: user.phoneE164,
                    role: user.role,
                    isActive: user.isActive,
                    pin: user.pin,
                    createdAt: user.createdAt,
                    updatedAt: user.updatedAt,
                    createdByUserId: user.createdByUserId,
                    updatedByUserId: user.updatedByUserId
                )
                
                // Update the local cache with the corrected user
                DispatchQueue.main.async { [weak self] in
                    if let index = self?.users.firstIndex(where: { 
                        $0.displayName == user.displayName && $0.phoneE164 == user.phoneE164 
                    }) {
                        self?.users[index] = correctedUser
                        print("✅ Updated local cache with correct Firestore ID")
                    }
                }
                
                // Now perform the update with the correct ID
                self?.performFirestoreUpdate(user: correctedUser, userData: userData)
            }
    }
    
    /// Verify that the Firestore update actually persisted
    private func verifyFirestoreUpdate(_ user: User) {
        print("🔍 Verifying Firestore update for user: \(user.displayName)")
        db.collection(collectionName).document(user.id).getDocument { document, error in
            if let error = error {
                print("❌ Verification failed - could not read document: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ Verification failed - document does not exist")
                return
            }
            
            do {
                let firestoreUser = try document.data(as: User.self)
                print("🔍 Firestore document verification:")
                print("  - Display Name: \(firestoreUser.displayName)")
                print("  - Role: \(firestoreUser.role.rawValue)")
                print("  - Is Active: \(firestoreUser.isActive)")
                print("  - PIN: \(firestoreUser.pin ?? "nil")")
                print("  - Updated At: \(firestoreUser.updatedAt)")
                
                // Check if PIN matches what we expected
                if firestoreUser.pin == user.pin {
                    print("✅ PIN verification successful: \(firestoreUser.pin ?? "nil")")
                } else {
                    print("❌ PIN verification failed!")
                    print("  Expected: \(user.pin ?? "nil")")
                    print("  Actual: \(firestoreUser.pin ?? "nil")")
                }
            } catch {
                print("❌ Verification failed - could not decode user: \(error.localizedDescription)")
            }
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
    
    /// Force refresh users from Firestore (useful for debugging)
    func forceRefreshFromFirestore() {
        print("🔄 Force refreshing users from Firestore...")
        fetchAllUsers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    print("✅ Force refresh successful: \(users.count) users loaded")
                    self?.users = users
                case .failure(let error):
                    print("❌ Force refresh failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Clean up duplicate users in Firebase (by phone number or display name)
    func cleanupDuplicateUsers() {
        print("🧹 Starting cleanup of duplicate users...")
        
        let usersByPhone = Dictionary(grouping: users) { $0.phoneE164 }
        let usersByName = Dictionary(grouping: users) { $0.displayName.lowercased() }
        
        var duplicatesToDelete: [User] = []
        
        // Find duplicates by phone number
        for (phone, phoneUsers) in usersByPhone {
            guard let phone = phone, phoneUsers.count > 1 else { continue }
            print("🧹 Found \(phoneUsers.count) users with phone \(phone)")
            
            // Keep the most recent user, mark others for deletion
            let sortedUsers = phoneUsers.sorted { $0.updatedAt > $1.updatedAt }
            duplicatesToDelete.append(contentsOf: sortedUsers.dropFirst())
        }
        
        // Find duplicates by display name
        for (name, nameUsers) in usersByName {
            guard nameUsers.count > 1 else { continue }
            print("🧹 Found \(nameUsers.count) users with name '\(name)'")
            
            // Keep the most recent user, mark others for deletion
            let sortedUsers = nameUsers.sorted { $0.updatedAt > $1.updatedAt }
            duplicatesToDelete.append(contentsOf: sortedUsers.dropFirst())
        }
        
        // Remove duplicates from the list
        let uniqueDuplicates = Array(Set(duplicatesToDelete))
        
        if !uniqueDuplicates.isEmpty {
            print("🧹 Found \(uniqueDuplicates.count) duplicate users to delete:")
            for user in uniqueDuplicates {
                print("  - \(user.displayName) (ID: \(user.id)) - Phone: \(user.phoneE164 ?? "none")")
                delete(user)
            }
        } else {
            print("🧹 No duplicate users found")
        }
    }
    
    /// Debug method to check current user state
    func debugUserState() {
        print("🔍 DEBUG: Current user state")
        print("🔍 Users in cache: \(users.count)")
        for user in users {
            print("  - \(user.displayName) (ID: \(user.id))")
            print("    Role: \(user.role.rawValue)")
            print("    Active: \(user.isActive)")
            print("    PIN: \(user.pin ?? "nil")")
            print("    Updated: \(user.updatedAt)")
        }
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
            print("  - \(user.displayName) (\(user.role.rawValue)) - Active: \(user.isActive) - PIN: \(user.pin ?? "none") - Phone: \(user.phoneE164 ?? "none")")
        }
        #endif
        
        // Find user with exact PIN match (custom PIN or phone-based PIN)
        if let userWithPin = users.first(where: { $0.pin == pin && $0.isActive }) {
            #if DEBUG
            print("🔐 Found user with PIN: \(userWithPin.displayName)")
            #endif
            completion(.success(userWithPin))
            return
        }
        
        #if DEBUG
        print("🔐 No user found with PIN: \(pin)")
        print("🔐 Users must have custom PINs or phone-based PINs")
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

// MARK: - Static Helper Methods

/// Generate PIN from last 4 digits of phone number
func generatePinFromPhone(_ phoneE164: String?) -> String? {
    guard let phone = phoneE164, !phone.isEmpty else { return nil }
    
    // Remove all non-digit characters
    let digits = phone.filter { $0.isNumber }
    
    // Take last 4 digits
    guard digits.count >= 4 else { return nil }
    
    let lastFour = String(digits.suffix(4))
    print("🔐 Generated PIN from phone \(phone): \(lastFour)")
    return lastFour
}

/// Create a new user with auto-generated PIN from phone number
func createUserWithPhonePin(displayName: String, phoneE164: String, role: UserRole, createdByUserId: String? = nil) -> User {
    let pin = generatePinFromPhone(phoneE164) ?? "0000" // fallback if phone invalid
    
    let user = User(
        id: UUID().uuidString,
        displayName: displayName,
        phoneE164: phoneE164,
        role: role,
        isActive: true,
        pin: pin,
        createdAt: Date(),
        updatedAt: Date(),
        createdByUserId: createdByUserId,
        updatedByUserId: nil
    )
    
    print("👤 Created user with phone-based PIN:")
    print("  - Name: \(displayName)")
    print("  - Phone: \(phoneE164)")
    print("  - PIN: \(pin)")
    print("  - Role: \(role.rawValue)")
    
    return user
}
// END
