//
//  Toolbar+SidebarToggle.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import SwiftUI

// ───── ViewModifier: Remove system-injected sidebar toggle (iOS 17+) ─────
private struct RemoveSystemSidebarToggleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            // iOS 17+ lets us remove the auto "sidebarToggle" button
            content.toolbar(removing: .sidebarToggle)
        } else {
            // pre‑iOS 17: nothing to remove
            content
        }
    }
}
// ───── END ViewModifier ─────

// ───── Public API: .removeSystemSidebarToggle() ─────
public extension View {
    func removeSystemSidebarToggle() -> some View {
        self.modifier(RemoveSystemSidebarToggleModifier())
    }
}
// ───── END Public API ─────

// ───── Preview Template ─────
#Preview {
    Text("Toolbar Shim Preview")
        .removeSystemSidebarToggle()
        .padding()
}
