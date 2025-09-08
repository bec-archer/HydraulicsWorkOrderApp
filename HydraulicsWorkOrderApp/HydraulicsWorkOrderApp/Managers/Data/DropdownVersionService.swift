//
//  DropdownVersionService.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//

import Foundation
import SwiftUI

// MARK: - Version Mismatch Severity
enum VersionMismatchSeverity {
    case low
    case medium
    case high
    
    var color: Color {
        switch self {
        case .low:
            return .yellow
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low:
            return "exclamationmark.triangle"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Version Mismatch
struct VersionMismatch {
    let itemVersion: Int
    let currentVersion: Int
    let severity: VersionMismatchSeverity
    let description: String
}

// MARK: - Dropdown Version Service
@MainActor
class DropdownVersionService: ObservableObject {
    static let shared = DropdownVersionService()
    
    private init() {}
    
    /// Check if an item has a version mismatch
    func hasVersionMismatch(_ item: WO_Item) -> Bool {
        return item.dropdownSchemaVersion != DropdownSchema.currentVersion
    }
    
    /// Get detailed version mismatch information
    func getVersionMismatch(_ item: WO_Item) -> VersionMismatch? {
        guard hasVersionMismatch(item) else { return nil }
        
        let itemVersion = item.dropdownSchemaVersion
        let currentVersion = DropdownSchema.currentVersion
        let versionDiff = currentVersion - itemVersion
        
        let severity: VersionMismatchSeverity
        let description: String
        
        if versionDiff > 2 {
            severity = .high
            description = "This item uses a very outdated schema and cannot be edited. Please contact an administrator."
        } else if versionDiff > 0 {
            severity = .medium
            description = "This item uses an older schema version. Some features may not be available."
        } else {
            severity = .low
            description = "This item uses a newer schema version. Some features may not be available."
        }
        
        return VersionMismatch(
            itemVersion: itemVersion,
            currentVersion: currentVersion,
            severity: severity,
            description: description
        )
    }
    
    /// Check if an item can be edited based on version mismatch
    func canEditItem(_ item: WO_Item) -> Bool {
        guard let mismatch = getVersionMismatch(item) else { return true }
        return mismatch.severity != .high
    }
    
    /// Get all items with version mismatches
    func getMismatchedItems(_ items: [WO_Item]) -> [WO_Item] {
        return items.filter { hasVersionMismatch($0) }
    }
    
    /// Get items that cannot be edited due to version mismatch
    func getNonEditableItems(_ items: [WO_Item]) -> [WO_Item] {
        return items.filter { !canEditItem($0) }
    }
}