//
//  VersionMismatchWarningView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//

import SwiftUI

// MARK: - VersionMismatchWarningView
struct VersionMismatchWarningView: View {
    let item: WO_Item
    let onUpdateSchema: (() -> Void)?
    
    @StateObject private var versionService = DropdownVersionService.shared
    @EnvironmentObject private var appState: AppState
    
    // MARK: - Computed Properties
    private var hasMismatch: Bool {
        versionService.hasVersionMismatch(item)
    }
    
    private var mismatch: VersionMismatch? {
        versionService.getVersionMismatch(item)
    }
    
    private var canUpdateSchema: Bool {
        appState.isAdmin || appState.isSuperAdmin
    }
    
    // MARK: - Body
    var body: some View {
        if hasMismatch, let mismatch = mismatch {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: mismatch.severity.icon)
                        .foregroundColor(mismatch.severity.color)
                        .font(.subheadline)
                    
                    Text("Schema Version Mismatch")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(mismatch.severity.color)
                    
                    Spacer()
                }
                
                Text(mismatch.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Item Version: \(mismatch.itemVersion)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Current Version: \(mismatch.currentVersion)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                if canUpdateSchema {
                    Button(action: {
                        onUpdateSchema?()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Update Schema")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(mismatch.severity.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(mismatch.severity.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - VersionMismatchBanner
struct VersionMismatchBanner: View {
    let items: [WO_Item]
    
    @StateObject private var versionService = DropdownVersionService.shared
    @EnvironmentObject private var appState: AppState
    
    // MARK: - Computed Properties
    private var mismatchedItems: [WO_Item] {
        items.filter { versionService.hasVersionMismatch($0) }
    }
    
    private var hasMismatches: Bool {
        !mismatchedItems.isEmpty
    }
    
    private var highSeverityCount: Int {
        mismatchedItems.filter { 
            versionService.getVersionMismatch($0)?.severity == .high 
        }.count
    }
    
    private var canUpdateSchema: Bool {
        appState.isAdmin || appState.isSuperAdmin
    }
    
    // MARK: - Body
    var body: some View {
        if hasMismatches {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Schema Version Issues")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text("\(mismatchedItems.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if highSeverityCount > 0 {
                    Text("\(highSeverityCount) items have high-severity mismatches and cannot be edited")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if canUpdateSchema {
                    Button(action: {
                        // TODO: Implement bulk schema update
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Update All Schemas")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Preview
#Preview("Version Mismatch Warning") {
    VStack(spacing: 16) {
        VersionMismatchWarningView(
            item: WO_Item(
                dropdowns: ["type": "OldType"],
                dropdownSchemaVersion: 1
            ),
            onUpdateSchema: {
                print("Update schema tapped")
            }
        )
        
        VersionMismatchWarningView(
            item: WO_Item(
                dropdowns: ["type": "OldType", "size": "OldSize"],
                dropdownSchemaVersion: 0
            ),
            onUpdateSchema: {
                print("Update schema tapped")
            }
        )
    }
    .padding()
    .environmentObject(AppState.shared)
}

#Preview("Version Mismatch Banner") {
    VStack(spacing: 16) {
        VersionMismatchBanner(
            items: [
                WO_Item(dropdowns: [:], dropdownSchemaVersion: 1),
                WO_Item(dropdowns: [:], dropdownSchemaVersion: 0),
                WO_Item(dropdowns: [:], dropdownSchemaVersion: 2)
            ]
        )
    }
    .padding()
    .environmentObject(AppState.shared)
}
