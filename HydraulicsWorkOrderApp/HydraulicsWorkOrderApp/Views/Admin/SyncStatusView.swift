//
//  SyncStatusView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//


// ───── SYNC STATUS VIEW ─────
import SwiftUI

/// Shows the health of Firebase + SQLite sync.
/// For now, it displays placeholder values; later we’ll hook it into `SyncManager`.
struct SyncStatusView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // ───── BODY ─────
        NavigationStack {
            List {
                Section("Firebase") {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Last Sync: Just now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("SQLite Backup") {
                    Label("Healthy", systemImage: "externaldrive.fill")
                        .foregroundStyle(.blue)
                    Text("Last Backup: Just now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Queue") {
                    Label("0 Pending Uploads", systemImage: "tray.fill")
                        .foregroundStyle(.gray)
                }
            }
            .navigationTitle("Sync Status")
        }
        // END
    }
}

// ───── PREVIEW ─────
#Preview {
    let s = AppState.previewLoggedIn(role: .admin)
    SyncStatusView()
        .environmentObject(s)
}
// END