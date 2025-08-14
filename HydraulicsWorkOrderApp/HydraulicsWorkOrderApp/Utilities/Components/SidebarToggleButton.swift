//
//  SidebarToggleButton.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//


//
//  SidebarToggleButton.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import SwiftUI

// ───── Yellow Sidebar Toggle Button (Reusable) ─────
struct SidebarToggleButton: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button {
            appState.toggleSidebar()
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color(red: 1.0, green: 0.7725, blue: 0.0)) // #FFC500
                .padding(.horizontal, 4)
                .accessibilityLabel("Toggle Sidebar")
        }
        .buttonStyle(.plain)
    }
    // END body
}

// ───── Preview Template ─────
#Preview {
    SidebarToggleButton()
        .environmentObject(AppState.shared)
}
