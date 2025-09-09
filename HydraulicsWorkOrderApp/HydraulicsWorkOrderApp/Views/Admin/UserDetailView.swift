//
//  UserDetailView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//
// ───── USER DETAIL VIEW ─────
import SwiftUI

struct UserDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var db = UsersDatabase.shared
    let user: User
    @State private var showEdit = false
    
    // Get the current user data from the database
    private var currentUser: User? {
        db.users.first { $0.id == user.id }
    }

    private var canEditBasics: Bool {
        guard let currentUser = currentUser else { return false }
        return (appState.isManager && currentUser.role == .tech) ||
               (appState.isAdmin   && currentUser.role != .superadmin) ||
               appState.isSuperAdmin
    }
    private var canToggleActive: Bool { canEditBasics }
    private var canChangeRole: Bool   { 
        guard let currentUser = currentUser else { return false }
        return appState.isSuperAdmin || (appState.isAdmin && currentUser.role != .superadmin) 
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let currentUser = currentUser {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(currentUser.displayName).font(.title2).bold()
                            Text(currentUser.role.rawValue.capitalized).font(.subheadline).foregroundStyle(.secondary)
                            if let phone = currentUser.phoneE164, !phone.isEmpty {
                                Text("Phone: \(phone.formattedPhoneNumber)").foregroundStyle(.blue).underline()
                                    .onTapGesture { call(phone) }
                            }
                            HStack(spacing: 8) {
                                Circle().frame(width: 10, height: 10)
                                    .foregroundStyle(currentUser.isActive ? .green : .gray)
                                Text(currentUser.isActive ? "Active" : "Inactive").font(.footnote)
                            }
                        }
                    }
                } else {
                    Text("User not found").foregroundStyle(.red)
                }

                HStack {
                    if canEditBasics {
                        Button("Edit") { showEdit = true }.buttonStyle(.borderedProminent)
                    }
                    if canToggleActive, let currentUser = currentUser {
                        Button(currentUser.isActive ? "Deactivate" : "Activate") {
                            print("🔄 Toggling active status for user: \(currentUser.displayName)")
                            print("🔄 Current isActive: \(currentUser.isActive)")
                            
                            // Create a proper copy with all fields preserved
                            let updatedUser = User(
                                id: currentUser.id,
                                displayName: currentUser.displayName,
                                phoneE164: currentUser.phoneE164,
                                role: currentUser.role,
                                isActive: !currentUser.isActive, // Toggle the active status
                                pin: currentUser.pin,
                                createdAt: currentUser.createdAt,
                                updatedAt: Date(), // Update the timestamp
                                createdByUserId: currentUser.createdByUserId,
                                updatedByUserId: appState.currentUser?.id
                            )
                            
                            print("🔄 New isActive: \(updatedUser.isActive)")
                            print("🔄 Calling db.update() for user: \(updatedUser.displayName)")
                            db.update(updatedUser)
                        }.buttonStyle(.bordered)
                    }
                    if canChangeRole {
                        Button("Change Role") { showEdit = true }.buttonStyle(.bordered)
                    }
                }

                Divider()

                // "My Work Items" (stub): WO_Items whose status was changed by this user, excluding "Checked In".
                if let currentUser = currentUser {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Work Items by \(currentUser.displayName)").font(.headline)
                        Text("Shows WO_Items where status changed by this user (≠ Checked In).")
                            .font(.footnote).foregroundStyle(.secondary)
                        NavigationLink(destination: MyWorkItemsView(user: currentUser)) {
                            Text("View Work Items")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("User Detail")
        .sheet(isPresented: $showEdit) {
            if let currentUser = currentUser {
                UserEditView(mode: .edit, user: currentUser).environmentObject(appState)
            }
        }
        // END
    }

    private func call(_ e164: String) {
        if let url = URL(string: "tel://\(e164.replacingOccurrences(of: "+", with: ""))") {
            UIApplication.shared.open(url)
        }
    }
}

// ───── PREVIEW ─────
#Preview {
    let s = AppState.previewLoggedIn(role: .admin)
    let u = User(id: "u1", displayName: "Jane Tech", phoneE164: "+12345550123", role: .tech, isActive: true, createdAt: .now, updatedAt: .now, createdByUserId: nil, updatedByUserId: nil)
    return NavigationStack { UserDetailView(user: u).environmentObject(s) }
}
// END
