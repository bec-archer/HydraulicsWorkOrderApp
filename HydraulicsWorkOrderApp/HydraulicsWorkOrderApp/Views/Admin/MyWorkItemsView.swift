//
//  MyWorkItemsView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//

// ───── MY WORK ITEMS VIEW ─────
import SwiftUI
import Foundation



/// Shows WO_Items filtered by user and status (excluding "Checked In")
/// Filters: statusHistory.status != "Checked In" && statusHistory.user == selectedUser.displayName
struct MyWorkItemsView: View {
    let user: User
    @StateObject private var workOrdersDB = WorkOrdersDatabase.shared
    @State private var filteredItems: [WO_Item] = []
    @State private var isLoading = true

    var body: some View {
        // ───── BODY ─────
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading work items...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Work Items Found")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("\(user.displayName) hasn't worked on any items yet, or all items are still in 'Checked In' status.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            WorkItemRow(item: item, workOrder: findWorkOrder(for: item))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Work Items by \(user.displayName)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadFilteredItems()
        }
        // END
    }

    // MARK: - Private Methods

    private func loadFilteredItems() {
        isLoading = true
        
        // TODO: Replace with proper WorkOrdersDatabase fetch and filtering
        // Filter: statusHistory.status != "Checked In" && statusHistory.user == user.displayName
        // For now, use placeholder logic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.filteredItems = self.getPlaceholderItems()
            self.isLoading = false
        }
    }

    private func getPlaceholderItems() -> [WO_Item] {
        // TODO: Replace with actual filtering logic from WorkOrdersDatabase
        // Filter: statusHistory.status != "Checked In" && statusHistory.user == user.displayName
        // Implementation should:
        // 1. Fetch all WorkOrders from WorkOrdersDatabase
        // 2. Extract all WO_Items from WorkOrders
        // 3. Filter items where statusHistory contains entry with:
        //    - status != "Checked In" AND user == selectedUser.displayName
        // 4. Sort by most recent status change timestamp
        
        // Placeholder items for demonstration
        return [
            WO_Item(
                id: UUID(),
                itemNumber: nil,
                assetTagId: nil,
                type: "Hydraulic Pump",
                imageUrls: [],
                thumbUrls: [],
                localImages: [],
                dropdowns: [:],
                dropdownSchemaVersion: 1,
                reasonsForService: [],
                reasonNotes: nil,
                completedReasons: [],
                statusHistory: [
                    WO_Status(status: "Checked In", user: "Tech", timestamp: Date().addingTimeInterval(-86400), notes: nil),
                    WO_Status(status: "In Progress", user: user.displayName, timestamp: Date().addingTimeInterval(-3600), notes: "Started repair work")
                ],
                notes: [],
                testResult: nil,
                partsUsed: nil,
                hoursWorked: nil,
                estimatedCost: nil,
                finalCost: nil,
                assignedTo: "",
                isFlagged: false,
                tagReplacementHistory: nil
            ),
            WO_Item(
                id: UUID(),
                itemNumber: nil,
                assetTagId: nil,
                type: "Control Valve",
                imageUrls: [],
                thumbUrls: [],
                localImages: [],
                dropdowns: [:],
                dropdownSchemaVersion: 1,
                reasonsForService: [],
                reasonNotes: nil,
                completedReasons: [],
                statusHistory: [
                    WO_Status(status: "Checked In", user: "Tech", timestamp: Date().addingTimeInterval(-172800), notes: nil),
                    WO_Status(status: "In Progress", user: user.displayName, timestamp: Date().addingTimeInterval(-86400), notes: "Valve disassembly complete"),
                    WO_Status(status: "Done", user: user.displayName, timestamp: Date().addingTimeInterval(-43200), notes: "Repair completed successfully")
                ],
                notes: [],
                testResult: nil,
                partsUsed: nil,
                hoursWorked: nil,
                estimatedCost: nil,
                finalCost: nil,
                assignedTo: "",
                isFlagged: false,
                tagReplacementHistory: nil
            )
        ]
    }

    private func findWorkOrder(for item: WO_Item) -> WorkOrder? {
        // TODO: Replace with actual WorkOrdersDatabase lookup
        // For now, return nil (placeholder)
        return nil
    }
}

// MARK: - Supporting Views

/// Row view for displaying a work item with basic info
private struct WorkItemRow: View {
    let item: WO_Item
    let workOrder: WorkOrder?
    
    // Compute current status from statusHistory
    private var currentStatus: String {
        item.statusHistory.last?.status ?? "Unknown"
    }
    
    // Get most recent note text for display
    private var recentNoteText: String {
        item.notes.last?.text ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.type)
                    .font(.headline)
                Spacer()
                StatusBadge(status: currentStatus)
            }
            
            if let workOrder = workOrder {
                Text("WO: \(workOrder.workOrderNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let lastStatus = item.statusHistory.last {
                HStack {
                    Text("Last updated by \(lastStatus.user)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(lastStatus.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Note: Placeholder items have empty notes array, so this won't show
            // TODO: When real data is loaded, this will display the most recent note
            if !recentNoteText.isEmpty {
                Text(recentNoteText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// Note: Using existing StatusBadge component from Views/Components/StatusBadge.swift

// ───── PREVIEW ─────
#Preview {
    let user = User(
        id: "u1",
        displayName: "Jane Tech",
        phoneE164: "+12345550123",
        role: .tech,
        isActive: true,
        createdAt: .now,
        updatedAt: .now,
        createdByUserId: nil,
        updatedByUserId: nil
    )
    
    return MyWorkItemsView(user: user)
}
// END
