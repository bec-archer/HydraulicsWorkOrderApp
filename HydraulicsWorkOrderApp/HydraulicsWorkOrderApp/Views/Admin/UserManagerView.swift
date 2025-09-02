//
//  UserManagerView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//

// ───── USER MANAGER VIEW ─────
import SwiftUI

/// Top-level Admin/SuperAdmin entry point for managing users.
/// This is intentionally minimal and non-breaking: it wraps `UsersListView`
/// in its own NavigationStack so it can be launched from the Admin area
/// without altering the sidebar or global navigation.
struct UserManagerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // ───── BODY ─────
        NavigationStack {
            UsersListView()
                .environmentObject(appState)
                .navigationTitle("User Manager")
        }
        // END
    }
}

// ───── PREVIEW ─────
#Preview {
    // Use the AppState preview helper to emulate Admin
    let s = AppState.previewLoggedIn(role: .admin)
    UserManagerView()
        .environmentObject(s)
}
// END
