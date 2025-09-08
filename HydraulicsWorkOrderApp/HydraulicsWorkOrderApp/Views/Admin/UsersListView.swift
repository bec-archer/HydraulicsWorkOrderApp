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

    private var canAddUser: Bool {
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
                        }
                    }
                }
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
        .onAppear { db.loadInitial() }
        // END
    }

    private var results: [User] { db.searchUsers(query: query) }

    private func call(_ e164: String) {
        if let url = URL(string: "tel://\(e164.replacingOccurrences(of: "+", with: ""))") {
            UIApplication.shared.open(url)
        }
    }
}

// ───── PREVIEW ─────
#Preview {
    let s = AppState.previewLoggedIn(role: .admin)
    NavigationStack { UsersListView().environmentObject(s) }
}
// END
