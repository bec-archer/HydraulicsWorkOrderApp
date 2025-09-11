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
    @State private var pin: String = ""

    private var canAdjustRole: Bool {
        appState.isSuperAdmin || (appState.isAdmin && role != .superadmin)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Info")) {
                    TextField("Display Name", text: $displayName)
                    TextField("Phone (+15551234567)", text: $phoneE164)
                    TextField("PIN (4-8 digits, leave empty for default role PIN)", text: $pin)
                        .keyboardType(.numberPad)
                }
                Section(header: Text("Role & Status")) {
                    Picker("Role", selection: $role) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.rawValue.capitalized).tag(role)
                        }
                    }
                    Toggle("Active", isOn: $isActive)
                }
                Section {
                    Button("Save") { save() }
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationTitle("User")
            .onAppear { bootstrap() }
        }
    }

    private func bootstrap() {
        if let u = user, mode == .edit {
            displayName = u.displayName
            phoneE164  = u.phoneE164 ?? ""
            role       = u.role
            isActive   = u.isActive
            pin        = u.pin ?? ""
        }
    }

    private func save() {
        let now = Date()
        if mode == .create {
            // Generate temporary pin from last 4 digits of phone number
            let temporaryPin = generateTemporaryPin(from: phoneE164)
            
            let new = User(
                id: UUID().uuidString, 
                displayName: displayName,
                phoneE164: phoneE164.isEmpty ? nil : phoneE164,
                role: role, 
                isActive: isActive,
                pin: temporaryPin,
                createdAt: now, 
                updatedAt: now,
                createdByUserId: nil, 
                updatedByUserId: nil
            )
            db.create(new)
        } else if var u = user {
            u.displayName = displayName
            u.phoneE164   = phoneE164.isEmpty ? nil : phoneE164
            u.role        = role
            u.isActive    = isActive
            u.pin         = pin.isEmpty ? nil : pin
            u.updatedAt   = now
            db.update(u)
        }
        dismiss()
    }
    
    /// Generate temporary pin from last 4 digits of phone number
    private func generateTemporaryPin(from phoneNumber: String) -> String? {
        // Remove all non-digit characters from phone number
        let digitsOnly = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Return last 4 digits if phone number has at least 4 digits
        if digitsOnly.count >= 4 {
            return String(digitsOnly.suffix(4))
        }
        
        // If phone number has fewer than 4 digits, return nil (will use default role pin)
        return nil
    }
}

#Preview {
    UserEditView(mode: .create, user: nil)
        .environmentObject(AppState.previewLoggedIn(role: .superadmin))
}
