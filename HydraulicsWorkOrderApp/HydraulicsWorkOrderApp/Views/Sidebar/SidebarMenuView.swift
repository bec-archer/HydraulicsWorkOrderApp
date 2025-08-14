//
//  SidebarMenuView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 SidebarMenuView.swift
// Persistent sidebar for NavigationSplitView — uses shared
// SidebarMenuContent for all menu items.
// ─────────────────────────────────────────────────────────────

struct SidebarMenuView: View {
    var body: some View {
        SidebarMenuContent()
            .listStyle(.sidebar)
            .navigationTitle("Sidebar")
    }
}

// ───── Preview Template ─────
#Preview {
    SidebarMenuView()
        .environmentObject(AppState.shared)
}
