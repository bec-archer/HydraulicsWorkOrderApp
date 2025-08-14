//
//  SidebarMenuView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 SidebarMenuSheet.swift
// A lightweight sidebar presented as a sheet. Uses shared
// SidebarMenuContent with a dismiss action.
// ─────────────────────────────────────────────────────────────

struct SidebarMenuSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SidebarMenuContent(dismissAction: { dismiss() })
                .listStyle(.insetGrouped)
                .navigationTitle("Sidebar")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                            .foregroundStyle(.primary)
                    }
                }
        }
    }
}

// ───── Preview Template ─────
#Preview {
    SidebarMenuSheet()
        .environmentObject(AppState.shared)
}
