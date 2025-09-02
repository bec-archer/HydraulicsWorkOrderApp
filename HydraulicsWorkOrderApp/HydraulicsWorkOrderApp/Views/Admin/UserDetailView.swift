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

    private var canEditBasics: Bool {
        (appState.isManager && user.role == .tech) ||
        (appState.isAdmin   && user.role != .superadmin) ||
        appState.isSuperAdmin
    }
    private var canToggleActive: Bool { canEditBasics }
    private var canChangeRole: Bool   { appState.isSuperAdmin || (appState.isAdmin && user.role != .superadmin) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(user.displayName).font(.title2).bold()
                        Text(user.role.rawValue.capitalized).font(.subheadline).foregroundStyle(.secondary)
                        if let phone = user.phoneE164, !phone.isEmpty {
                            Text("Phone: \(phone.formattedPhoneNumber)").foregroundStyle(.blue).underline()
                                .onTapGesture { call(phone) }
                        }
                        HStack(spacing: 8) {
                            Circle().frame(width: 10, height: 10)
                                .foregroundStyle(user.isActive ? .green : .gray)
                            Text(user.isActive ? "Active" : "Inactive").font(.footnote)
                        }
                    }
                }

                HStack {
                    if canEditBasics {
                        Button("Edit") { showEdit = true }.buttonStyle(.borderedProminent)
                    }
                    if canToggleActive {
                        Button(user.isActive ? "Deactivate" : "Activate") {
                            var copy = user; copy.isActive.toggle(); db.update(copy)
                        }.buttonStyle(.bordered)
                    }
                    if canChangeRole {
                        Button("Change Role") { showEdit = true }.buttonStyle(.bordered)
                    }
                }

                Divider()

                // “My Work Items” (stub): WO_Items whose status was changed by this user, excluding "Checked In".
                VStack(alignment: .leading, spacing: 8) {
                    Text("Work Items by \(user.displayName)").font(.headline)
                    Text("Shows WO_Items where status changed by this user (≠ Checked In). TODO: wire query to statusHistory.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("View Work Items") { /* TODO: navigate when data ready */ }
                }
            }
            .padding(16)
        }
        .navigationTitle("User Detail")
        .sheet(isPresented: $showEdit) {
            UserEditView(mode: .edit, user: user).environmentObject(appState)
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
