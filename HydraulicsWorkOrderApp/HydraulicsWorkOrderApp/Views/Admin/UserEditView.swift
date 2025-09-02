//
//  UserEditView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//
// ───── USER EDIT VIEW ─────
import SwiftUI

struct UserEditView: View {
    enum Mode { case create, edit }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var db = UsersDatabase.shared

    let mode: Mode
    let user: User?

    @State private var displayName: String = ""
    @State private var phoneE164: String = ""
    @State private var role: UserRole = .tech
    @State private var isActive: Bool = true

    private var canAdjustRole: Bool {
        appState.isSuperAdmin || (appState.isAdmin && role != .superadmin)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Display Name", text: $displayName).textInputAutocapitalization(.words)
                    TextField("Phone (+15551234567)", text: $phoneE164).keyboardType(.phonePad)
                }
                Section("Role & Status") {
                    Picker("Role", selection: $role) {
                        ForEach(UserRole.allCases, id: \.self) { r in
                            Text(r.rawValue.capitalized).tag(r)
                        }
                    }.disabled(!canAdjustRole)
                    Toggle("Active", isOn: $isActive).disabled(!canAdjustRole)
                }
                Section {
                    Button(mode == .create ? "Create User" : "Save Changes") { save() }
                        .buttonStyle(.borderedProminent)
                    Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                }
            }
            .navigationTitle(mode == .create ? "New User" : "Edit User")
            .onAppear { bootstrap() }
        }
        // END
    }

    private func bootstrap() {
        if let u = user, mode == .edit {
            displayName = u.displayName
            phoneE164  = u.phoneE164 ?? ""
            role       = u.role
            isActive   = u.isActive
        }
    }

    private func save() {
        let now = Date()
        if mode == .create {
            // SuperAdmin protections: Admin cannot create a SuperAdmin account
            if appState.isAdmin && role == .superadmin {
                // Silently ignore or show a toast in the calling view if desired.
                return
            }
            let new = User(id: UUID().uuidString, displayName: displayName,
                           phoneE164: phoneE164.isEmpty ? nil : phoneE164,
                           role: role, isActive: isActive,
                           createdAt: now, updatedAt: now,
                           createdByUserId: nil, updatedByUserId: nil)
            db.create(new)
        } else if var u = user {
            if appState.isAdmin && u.role == .superadmin { return } // protect SuperAdmin
            if appState.isAdmin && role == .superadmin { return } // prevent Admin from setting SuperAdmin
            u.displayName = displayName
            u.phoneE164   = phoneE164.isEmpty ? nil : phoneE164
            u.role        = role
            u.isActive    = isActive
            u.updatedAt   = now
            db.update(u)
        }
        dismiss()
    }
}

// ───── PREVIEW ─────
#Preview {
    let s = AppState.previewLoggedIn(role: .superadmin)
    return UserEditView(mode: .create, user: nil).environmentObject(s)
}
// END
