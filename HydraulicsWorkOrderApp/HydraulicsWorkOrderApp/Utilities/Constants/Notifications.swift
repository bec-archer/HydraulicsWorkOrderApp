//
//  Notifications.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/21/25.
//
import Foundation

// ───── App Notification Names (Single Source of Truth) ─────
// Centralized notification names used across the app.
// Keep this file as the only place that defines these constants.
// END header

public extension Notification.Name {
    // Image preview is ready for a WorkOrder card/list
    static let WOPreviewAvailable       = Notification.Name("WOPreviewAvailable")

    // A pending preview (thumbnail) has been updated/changed and should refresh
    static let WOPendingPreviewUpdated  = Notification.Name("WOPendingPreviewUpdated")

    // Common app events (predeclared to avoid scattershot additions later)
    static let WorkOrderSaved           = Notification.Name("WorkOrderSaved")
    static let WorkOrderDeleted         = Notification.Name("WorkOrderDeleted")
    static let CustomerUpdated          = Notification.Name("CustomerUpdated")
    static let DropdownsUpdated         = Notification.Name("DropdownsUpdated")
}
// END

// ───── Preview ─────
#if DEBUG
import SwiftUI
struct Notifications_Previews: PreviewProvider {
    static var previews: some View {
        Text("Notifications.swift constants loaded.")
            .padding()
    }
}
#endif
// END Preview
