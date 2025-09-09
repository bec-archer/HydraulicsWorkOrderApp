//
//  UsersListView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//
// ───── USERS LIST VIEW ─────
import SwiftUI

struct UsersListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var db = UsersDatabase.shared
    @State private var query: String = ""
    @State private var showAddSheet = false
    @State private var userToDelete: User?
    @State private var showDeleteConfirmation = false

    private var canAddUser: Bool {
        appState.isAdmin || appState.isSuperAdmin
    }
    
    private var canDeleteUser: Bool {
        appState.isAdmin || appState.isSuperAdmin
    }

    var body: some View {
        // ───── BODY: SEARCH + LIST ─────
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search by name, phone, or role", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List {
                ForEach(results, id: \.id) { user in
                    NavigationLink(destination: UserDetailView(user: user)) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName).font(.headline)
                                Text(user.role.rawValue.capitalized)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let phone = user.phoneE164, !phone.isEmpty {
                                Text(phone.formattedPhoneNumber)
                                    .foregroundStyle(.blue).underline()
                                    .onTapGesture { call(phone) }
                            }
                            Circle().frame(width: 10, height: 10)
                                .foregroundStyle(user.isActive ? .green : .gray)
                                .accessibilityLabel(user.isActive ? "Active" : "Inactive")
                            
                            // Delete button for deactivated users
                            if !user.isActive {
                                Button {
                                    print("🗑️ Delete button tapped for user: \(user.displayName)")
                                    userToDelete = user
                                    showDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canDeleteUser)
                                .opacity(canDeleteUser ? 1.0 : 0.3)
                                .onAppear {
                                    print("🗑️ Trash icon appeared for deactivated user: \(user.displayName), canDelete: \(canDeleteUser)")
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: canDeleteUser ? deleteUsers : nil)
            }
            .listStyle(.plain)

            if canAddUser {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add User", systemImage: "plus.circle.fill").font(.title3)
                }
                .padding(.horizontal).padding(.bottom, 16)
                .sheet(isPresented: $showAddSheet) {
                    UserEditView(mode: .create, user: nil)
                        .environmentObject(appState)
                }
            }
        }
        .navigationTitle("Users")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    print("🔄 Manual refresh requested")
                    db.loadInitial()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear { 
            print("📱 UsersListView: Loading fresh data from Firestore")
            db.loadInitial()
        }
        .confirmationDialog(
            "Delete User",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let user = userToDelete {
                Button("Delete \(user.displayName)", role: .destructive) {
                    deleteUser(user)
                }
                Button("Cancel", role: .cancel) {
                    userToDelete = nil
                }
            }
        } message: {
            if let user = userToDelete {
                Text("Are you sure you want to permanently delete \(user.displayName)? This action cannot be undone.")
            }
        }
        // END
    }

    private var results: [User] { db.searchUsers(query: query) }

    private func call(_ e164: String) {
        if let url = URL(string: "tel://\(e164.replacingOccurrences(of: "+", with: ""))") {
            UIApplication.shared.open(url)
        }
    }
    
    private func deleteUser(_ user: User) {
        print("🗑️ Attempting to delete user: \(user.displayName) (ID: \(user.id))")
        print("🗑️ User isActive: \(user.isActive)")
        print("🗑️ Current user ID: \(appState.currentUser?.id ?? "none")")
        
        // Only allow deletion of deactivated users
        guard !user.isActive else {
            print("⚠️ Cannot delete active user: \(user.displayName)")
            return
        }
        
        // Don't allow deletion of the current user
        if user.id == appState.currentUser?.id {
            print("⚠️ Cannot delete current user: \(user.displayName)")
            return
        }
        
        print("🗑️ Calling db.delete() for user: \(user.displayName)")
        db.delete(user)
        userToDelete = nil
        print("🗑️ Delete call completed for user: \(user.displayName)")
    }
    
    private func deleteUsers(offsets: IndexSet) {
        let usersToDelete = offsets.compactMap { index in
            let user = results[index]
            // Only allow deletion of deactivated users
            return !user.isActive && user.id != appState.currentUser?.id ? user : nil
        }
        
        for user in usersToDelete {
            db.delete(user)
        }
    }
}

// ───── PREVIEW ─────
#Preview {
    let s = AppState.previewLoggedIn(role: .admin)
    NavigationStack { UsersListView().environmentObject(s) }
}
// END
