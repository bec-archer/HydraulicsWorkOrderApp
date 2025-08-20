//
//  Notifications.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/20/25.
//


//
//  Notifications.swift
//  HydraulicsWorkOrderApp
//
//  Centralized Notification.Name definitions
//  Created by Bec Archer on 8/20/25.
//

import Foundation

extension Notification.Name {
    /// Posted when a WorkOrder's preview image (thumbnail) is updated asynchronously.
    static let WOPendingPreviewUpdated = Notification.Name("WOPendingPreviewUpdated")

    /// Posted when a WorkOrder is successfully saved to the database.
    static let WorkOrderSaved = Notification.Name("WorkOrderSaved")

    /// Posted when a Customer record is created or updated.
    static let CustomerUpdated = Notification.Name("CustomerUpdated")
}
