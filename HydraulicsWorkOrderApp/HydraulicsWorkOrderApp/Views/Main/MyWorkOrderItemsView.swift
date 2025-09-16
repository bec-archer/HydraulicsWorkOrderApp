//
//  MyWorkOrderItemsView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//

// ───── MY WORK ORDER ITEMS VIEW ─────
import SwiftUI
import Combine

/// Shows WO_Items for the currently logged-in user, filtered by status (excluding "Checked In")
/// Filters: statusHistory.status != "Checked In" && statusHistory.user == currentUser.displayName
struct MyWorkOrderItemsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var workOrdersDB = WorkOrdersDatabase.shared
    @State private var filteredItemData: [WorkOrderItemData] = []
    @State private var isLoading = true
    @State private var selectedItemForSheet: WorkOrderItemData?

    var body: some View {
        // ───── BODY ─────
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    ProgressView("Loading your work items...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if filteredItemData.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Work Items Found")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("You haven't worked on any items yet, or all items are still in 'Checked In' status.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(filteredItemData) { latestItem in
                        MyWorkOrderItemCard(
                            item: latestItem.item,
                            workOrder: latestItem.workOrder,
                            itemIndex: latestItem.itemIndex,
                            onTap: {
                                print("🔍 DEBUG: Tapped on item: \(latestItem.workOrder.workOrderNumber)-\(String(format: "%03d", latestItem.itemIndex + 1))")
                                print("🔍 DEBUG: Setting selectedItemForSheet: \(latestItem.workOrder.workOrderNumber)")
                                
                                // Set the selected item for the sheet
                                selectedItemForSheet = latestItem
                                
                                print("🔍 DEBUG: selectedItemForSheet is now: \(selectedItemForSheet?.workOrder.workOrderNumber ?? "nil")")
                            },
                            onDataChanged: {
                                print("🔍 DEBUG: Data changed callback triggered - refreshing specific item")
                                refreshSpecificItem(workOrderId: latestItem.workOrder.id, itemId: latestItem.item.id)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .navigationTitle("My Work Items")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFilteredItems()
        }
        .refreshable {
            loadFilteredItems()
        }
        .fullScreenCover(item: $selectedItemForSheet) { latestItem in
            ItemDetailSheetView(
                workOrder: latestItem.workOrder,
                item: latestItem.item,
                itemIndex: latestItem.itemIndex
            ) {
                selectedItemForSheet = nil
                // Refresh the data when sheet is dismissed
                print("🔍 DEBUG: Sheet dismissed, refreshing data")
                loadFilteredItems()
            }
            .environmentObject(appState)
        }
        // END
    }

    // MARK: - Private Methods

    private func loadFilteredItems() {
        print("🔍 DEBUG: loadFilteredItems called")
        isLoading = true
        
        Task {
            do {
                // Fetch all work orders from database
                let allWorkOrders = try await workOrdersDB.getAllWorkOrders()
                print("🔍 DEBUG: Retrieved \(allWorkOrders.count) work orders from database")
                
                // Filter to active work orders only
                let activeWorkOrders = allWorkOrders.filter { workOrder in
                    !workOrder.isDeleted && workOrder.status.lowercased() != "closed"
                }
                
                // Extract items where current user has made status/note updates (excluding "Checked In")
                var latestItemArray: [WorkOrderItemData] = []
                
                for workOrder in activeWorkOrders {
                    for (itemIndex, item) in workOrder.items.enumerated() {
                        // Check if this item has status history from current user (excluding "Checked In")
                        let userStatusUpdates = item.statusHistory.filter { status in
                            status.user == appState.currentUserName && 
                            status.status.lowercased() != "checked in"
                        }
                        
                        // Check if this item has notes from current user
                        let userNotes = item.notes.filter { note in
                            note.user == appState.currentUserName
                        }
                        
                        // Check if this item has completed reasons for service
                        let hasCompletedReasons = !item.completedReasons.isEmpty
                        
                        // Include if user has made any status updates, notes, or completed reasons
                        if !userStatusUpdates.isEmpty || !userNotes.isEmpty || hasCompletedReasons {
                            print("🔍 DEBUG: Found item for user - WO: \(workOrder.workOrderNumber), Item: \(itemIndex), Status: \(item.statusHistory.last?.status ?? "none"), CompletedReasons: \(item.completedReasons)")
                            latestItemArray.append(WorkOrderItemData(
                                item: item,
                                workOrder: workOrder,
                                itemIndex: itemIndex
                            ))
                        }
                    }
                }
                
                // Sort by most recent activity (status updates or notes)
                latestItemArray.sort { data1, data2 in
                    let latest1 = getLatestActivityTimestamp(for: data1.item)
                    let latest2 = getLatestActivityTimestamp(for: data2.item)
                    return latest1 > latest2
                }
                
                await MainActor.run {
                    self.filteredItemData = latestItemArray
                    self.isLoading = false
                }
                
            } catch {
                print("❌ Error loading work orders: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getLatestActivityTimestamp(for item: WO_Item) -> Date {
        var latestDate = Date.distantPast
        
        // Check latest status update
        for status in item.statusHistory {
            if status.timestamp > latestDate {
                latestDate = status.timestamp
            }
        }
        
        // Check latest note
        for note in item.notes {
            if note.timestamp > latestDate {
                latestDate = note.timestamp
            }
        }
        
        return latestDate
    }
    
    // MARK: - Specific Item Refresh
    private func refreshSpecificItem(workOrderId: String, itemId: UUID) {
        print("🔍 DEBUG: refreshSpecificItem called for workOrderId: \(workOrderId), itemId: \(itemId)")
        
        Task {
            do {
                // Get fresh data from database
                let allWorkOrders = try await workOrdersDB.getAllWorkOrders()
                
                // Find the updated work order
                if let updatedWorkOrder = allWorkOrders.first(where: { $0.id == workOrderId }) {
                    // Find the updated item
                    if let updatedItemIndex = updatedWorkOrder.items.firstIndex(where: { $0.id == itemId }) {
                        let updatedItem = updatedWorkOrder.items[updatedItemIndex]
                        
                        // Check if this item should be in our filtered list
                        let userStatusUpdates = updatedItem.statusHistory.filter { status in
                            status.user == appState.currentUserName && 
                            status.status.lowercased() != "checked in"
                        }
                        
                        let userNotes = updatedItem.notes.filter { note in
                            note.user == appState.currentUserName
                        }
                        
                        let hasCompletedReasons = !updatedItem.completedReasons.isEmpty
                        
                        let shouldInclude = !userStatusUpdates.isEmpty || !userNotes.isEmpty || hasCompletedReasons
                        
                        await MainActor.run {
                            if shouldInclude {
                                // Update the existing item in filteredItemData
                                if let existingIndex = filteredItemData.firstIndex(where: { $0.item.id == itemId }) {
                                    filteredItemData[existingIndex] = WorkOrderItemData(
                                        item: updatedItem,
                                        workOrder: updatedWorkOrder,
                                        itemIndex: updatedItemIndex
                                    )
                                    print("🔍 DEBUG: Updated existing item in filteredItemData")
                                } else {
                                    // Add new item if it wasn't there before
                                    filteredItemData.append(WorkOrderItemData(
                                        item: updatedItem,
                                        workOrder: updatedWorkOrder,
                                        itemIndex: updatedItemIndex
                                    ))
                                    print("🔍 DEBUG: Added new item to filteredItemData")
                                }
                            } else {
                                // Remove item if it no longer qualifies
                                filteredItemData.removeAll { $0.item.id == itemId }
                                print("🔍 DEBUG: Removed item from filteredItemData")
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error refreshing specific item: \(error)")
                // Fallback to full refresh
                loadFilteredItems()
            }
        }
    }
    
}

// MARK: - Data Structure
struct WorkOrderItemData: Identifiable {
    let id: UUID
    let item: WO_Item
    let workOrder: WorkOrder
    let itemIndex: Int
    
    init(item: WO_Item, workOrder: WorkOrder, itemIndex: Int) {
        self.id = item.id // Use the item's ID as the identifier to prevent view recreation
        self.item = item
        self.workOrder = workOrder
        self.itemIndex = itemIndex
    }
}

// MARK: - Custom Item Card for My Work Orders
struct MyWorkOrderItemCard: View {
    let item: WO_Item
    let workOrder: WorkOrder
    let itemIndex: Int
    let onTap: () -> Void
    let onDataChanged: (() -> Void)?
    
    @State private var partsUsedText: String = ""
    @State private var hoursWorkedText: String = ""
    @State private var costText: String = ""
    @State private var isEditingParts: Bool = false
    @State private var isSavingParts: Bool = false
    @State private var showStatusSelection: Bool = false
    @State private var itemForCompletion: WO_Item?
    @StateObject private var workOrdersDB = WorkOrdersDatabase.shared
    
    // Get current status from statusHistory
    private var currentStatus: String {
        item.statusHistory.last?.status ?? "Unknown"
    }
    
    // Get most recent note text for display
    private var recentNoteText: String {
        item.notes.last?.text ?? ""
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // ───── Left: Primary Image ─────
            VStack {
                if let firstImageURL = item.imageUrls.first {
                    AsyncImage(url: URL(string: firstImageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 300, height: 300)
                            .clipped()
                            .cornerRadius(12)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 300, height: 300)
                            .cornerRadius(12)
                    }
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 300, height: 300)
                        .cornerRadius(12)
                }
            }
            
            // ───── Right: Content ─────
            VStack(alignment: .leading, spacing: 8) {
                // ───── Header Row ─────
                HStack {
                    // Work Order Number
                    Text("\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Status Badge (Tappable)
                    Button(action: {
                        print("🔍 DEBUG: Status badge tapped for item: \(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
                        showStatusSelection = true
                    }) {
                        StatusBadge(status: currentStatus)
                    }
                    .buttonStyle(.plain)
                }
                
                // ───── View Details Button ─────
                HStack {
                    Spacer()
                    Button(action: onTap) {
                        Text("View Details")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 1.0, green: 0.77, blue: 0.0)) // #FFC500
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // ───── Item Type and Details ─────
                VStack(alignment: .leading, spacing: 6) {
                        Text(item.type)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        // Show dropdown details if available
                        if !item.dropdowns.isEmpty {
                            ForEach(Array(item.dropdowns.keys.sorted()), id: \.self) { key in
                                if let value = item.dropdowns[key], !value.isEmpty {
                                    HStack {
                                        Text("\(key):")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(value)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    
                    // ───── Customer Info (Tappable) ─────
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workOrder.customerName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            if !workOrder.customerPhone.isEmpty {
                                Text(workOrder.customerPhone)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Phone action button
                        if !workOrder.customerPhone.isEmpty {
                            Button(action: {
                                if let url = URL(string: "tel:\(workOrder.customerPhone)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Image(systemName: "phone")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // ───── Reasons for Service ─────
                    if !item.reasonsForService.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reasons for Service:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .onAppear {
                                    print("🔍 DEBUG: Reasons for Service section rendered")
                                    print("🔍 DEBUG: Number of reasons: \(item.reasonsForService.count)")
                                }
                            
                            ForEach(item.reasonsForService, id: \.self) { reason in
                                HStack(spacing: 8) {
                                    Button(action: {
                                        print("🔍 DEBUG: Toggle button tapped for reason: '\(reason)'")
                                        print("🔍 DEBUG: Current completedReasons: \(item.completedReasons)")
                                        print("🔍 DEBUG: Item ID: \(item.id)")
                                        print("🔍 DEBUG: Work Order ID: \(workOrder.id)")
                                        print("🔍 DEBUG: Item Index: \(itemIndex)")
                                        toggleReasonCompletion(reason)
                                    }) {
                                        Image(systemName: item.completedReasons.contains(reason) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(item.completedReasons.contains(reason) ? .green : .secondary)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // ───── Display reason with note for "Other" ─────
                                    if reason.lowercased().contains("other") && !(item.reasonNotes?.isEmpty ?? true) {
                                        Text("\(reason) • \(item.reasonNotes ?? "")")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    } else {
                                    Text(reason)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    
                    // ───── Recent Activity ─────
                    if let lastStatus = item.statusHistory.last {
                        HStack {
                            Text("Last updated by \(lastStatus.user)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(lastStatus.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // ───── Recent Note ─────
                    if !recentNoteText.isEmpty {
                        Text(recentNoteText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.top, 4)
                    }
                    
                // ───── Parts Used Section ─────
                partsUsedSection
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onAppear {
            // Initialize completion details from item
            partsUsedText = item.partsUsed ?? ""
            hoursWorkedText = item.hoursWorked ?? ""
            costText = item.finalCost ?? ""
            
            // Debug: Log item data
            print("🔍 DEBUG: MyWorkOrderItemCard onAppear")
            print("🔍 DEBUG: Item ID: \(item.id)")
            print("🔍 DEBUG: Item Type: \(item.type)")
            print("🔍 DEBUG: Reasons for Service: \(item.reasonsForService)")
            print("🔍 DEBUG: Completed Reasons: \(item.completedReasons)")
            print("🔍 DEBUG: Work Order ID: \(workOrder.id)")
            print("🔍 DEBUG: Work Order Number: \(workOrder.workOrderNumber)")
            print("🔍 DEBUG: Item Index: \(itemIndex)")
            print("🔍 DEBUG: Completion details - Parts: '\(item.partsUsed ?? "nil")', Hours: '\(item.hoursWorked ?? "nil")', Cost: '\(item.finalCost ?? "nil")'")
        }
        .onChange(of: item.partsUsed) { newValue in
            partsUsedText = newValue ?? ""
            print("🔍 DEBUG: Parts used changed to: '\(newValue ?? "nil")'")
        }
        .onChange(of: item.hoursWorked) { newValue in
            hoursWorkedText = newValue ?? ""
            print("🔍 DEBUG: Hours worked changed to: '\(newValue ?? "nil")'")
        }
        .onChange(of: item.finalCost) { newValue in
            costText = newValue ?? ""
            print("🔍 DEBUG: Final cost changed to: '\(newValue ?? "nil")'")
        }
        .sheet(isPresented: $showStatusSelection) {
            StatusSelectionView(
                currentStatus: currentStatus,
                onStatusSelected: { newStatus in
                    print("🔍 DEBUG: Status selected: \(newStatus)")
                    
                // Check if status is "Complete" - show completion details sheet first
                if newStatus.lowercased() == "complete" {
                    print("🔍 DEBUG: Complete status requested - showing completion details sheet")
                    print("🔍 DEBUG: Item ID: \(item.id), Index: \(itemIndex)")
                    
                    // First dismiss the status selection sheet
                    showStatusSelection = false
                    
                    // Set the item for completion details
                    itemForCompletion = item
                    print("🔍 DEBUG: itemForCompletion set to: \(item.id)")
                    // Note: Status will only change to Complete AFTER completion details are saved
                } else {
                    // For other statuses, update directly
                    Task {
                        await updateItemStatus(newStatus)
                    }
                    showStatusSelection = false
                }
                }
            )
        }
        .sheet(item: $itemForCompletion) { completionItem in
            CompletionDetailsSheet(
                workOrder: workOrder,
                item: completionItem,
                itemIndex: itemIndex,
                onCompletionDetailsSaved: { partsUsed, hoursWorked, cost in
                    print("🔍 DEBUG: CompletionDetailsSheet callback - Parts: '\(partsUsed)', Hours: '\(hoursWorked)', Cost: '\(cost)'")
                    Task {
                        // Only change status to Complete after completion details are saved
                        await updateItemStatusWithCompletion(
                            "Complete",
                            partsUsed: partsUsed,
                            hoursWorked: hoursWorked,
                            cost: cost
                        )
                        
                        // Notify parent view of data change
                        DispatchQueue.main.async {
                            onDataChanged?()
                        }
                    }
                    itemForCompletion = nil
                },
                onCompletionCancelled: {
                    // If user cancels, don't change the status - it remains as it was
                    print("🔍 DEBUG: Completion details sheet cancelled - status unchanged")
                    itemForCompletion = nil
                }
            )
            .onAppear {
                print("🔍 DEBUG: CompletionDetailsSheet presented for item: \(completionItem.id), index: \(itemIndex)")
            }
        }
    }
    
    // MARK: - Parts Used Section
    @ViewBuilder
    private var partsUsedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Completion Details")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isEditingParts {
                    Button("Cancel") {
                        // Reset to original values and stop editing
                        partsUsedText = item.partsUsed ?? ""
                        hoursWorkedText = item.hoursWorked ?? ""
                        costText = item.finalCost ?? ""
                        isEditingParts = false
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    Button("Edit") {
                        isEditingParts = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if isEditingParts {
                VStack(spacing: 8) {
                    // Parts Used Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Parts Used")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter parts used...", text: $partsUsedText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...3)
                            .font(.caption)
                    }
                    
                    // Hours Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hours")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter hours...", text: $hoursWorkedText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .font(.caption)
                    }
                    
                    // Cost Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cost")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter cost...", text: $costText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .font(.caption)
                    }
                    
                    HStack {
                        Button("Save") {
                            saveCompletionDetails()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .disabled(isSavingParts)
                        
                        if isSavingParts {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Spacer()
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    // Display Parts Used
                    if partsUsedText.isEmpty {
                        Text("No parts recorded yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text(partsUsedText)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    // Display Hours
                    if hoursWorkedText.isEmpty {
                        Text("No hours recorded yet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text("Hours: \(hoursWorkedText)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Display Cost
                    if costText.isEmpty {
                        Text("No cost recorded yet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text("Cost: $\(costText)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Save Completion Details
    private func saveCompletionDetails() {
        isSavingParts = true
        
        Task {
            do {
                // Create a copy of the work order with updated completion details
                var updatedWorkOrder = workOrder
                
                // Update all three fields
                updatedWorkOrder.items[itemIndex].partsUsed = partsUsedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : partsUsedText.trimmingCharacters(in: .whitespacesAndNewlines)
                updatedWorkOrder.items[itemIndex].hoursWorked = hoursWorkedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : hoursWorkedText.trimmingCharacters(in: .whitespacesAndNewlines)
                updatedWorkOrder.items[itemIndex].finalCost = costText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : costText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                updatedWorkOrder.items[itemIndex].lastModified = Date()
                updatedWorkOrder.items[itemIndex].lastModifiedBy = AppState.shared.currentUserName
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = AppState.shared.currentUserName
                
                // Save to database
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
                
                await MainActor.run {
                    isEditingParts = false
                    isSavingParts = false
                }
                
            } catch {
                print("❌ Error saving completion details: \(error)")
                await MainActor.run {
                    isSavingParts = false
                }
            }
        }
    }
    
    // MARK: - Toggle Reason Completion
    private func toggleReasonCompletion(_ reason: String) {
        print("🔍 DEBUG: toggleReasonCompletion called with reason: '\(reason)'")
        print("🔍 DEBUG: Starting toggle process...")
        
        // No optimistic update - let database update complete first
        print("🔍 DEBUG: Starting database update...")
        
        Task {
            do {
                print("🔍 DEBUG: Creating updated work order copy...")
                var updatedWorkOrder = workOrder
                
                print("🔍 DEBUG: Current completedReasons before toggle: \(updatedWorkOrder.items[itemIndex].completedReasons)")
                print("🔍 DEBUG: Checking if reason '\(reason)' is already completed...")
                
                if updatedWorkOrder.items[itemIndex].completedReasons.contains(reason) {
                    print("🔍 DEBUG: Reason is already completed, removing it...")
                    updatedWorkOrder.items[itemIndex].completedReasons.removeAll { $0 == reason }
                } else {
                    print("🔍 DEBUG: Reason is not completed, adding it...")
                    updatedWorkOrder.items[itemIndex].completedReasons.append(reason)
                }
                
                print("🔍 DEBUG: CompletedReasons after toggle: \(updatedWorkOrder.items[itemIndex].completedReasons)")
                
                print("🔍 DEBUG: Updating timestamps and user tracking...")
                updatedWorkOrder.items[itemIndex].lastModified = Date()
                updatedWorkOrder.items[itemIndex].lastModifiedBy = AppState.shared.currentUserName
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = AppState.shared.currentUserName
                
                print("🔍 DEBUG: Calling workOrdersDB.updateWorkOrder...")
                print("🔍 DEBUG: Work Order ID: \(updatedWorkOrder.id)")
                print("🔍 DEBUG: Work Order Number: \(updatedWorkOrder.workOrderNumber)")
                
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
                
                print("✅ DEBUG: Successfully updated work order in database")
                
                // Refresh the data after successful database update
                await MainActor.run {
                    print("🔍 DEBUG: Refreshing data after successful toggle...")
                    onDataChanged?()
                }
                
            } catch {
                print("❌ DEBUG: Error toggling reason completion: \(error)")
                print("❌ DEBUG: Error details: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("❌ DEBUG: NSError domain: \(nsError.domain)")
                    print("❌ DEBUG: NSError code: \(nsError.code)")
                    print("❌ DEBUG: NSError userInfo: \(nsError.userInfo)")
                }
                
                // If database update fails, refresh to get correct state
                await MainActor.run {
                    print("🔍 DEBUG: Database update failed, refreshing to correct state...")
                    onDataChanged?()
                }
            }
        }
    }
    
    // MARK: - Update Item Status
    private func updateItemStatus(_ newStatus: String) async {
        print("🔍 DEBUG: updateItemStatus called with status: '\(newStatus)'")
        print("🔍 DEBUG: Starting status update process...")
        
        do {
            print("🔍 DEBUG: Creating updated work order copy...")
            var updatedWorkOrder = workOrder
            
            // Add new status to status history
            let newStatusEntry = WO_Status(
                status: newStatus,
                user: AppState.shared.currentUserName,
                timestamp: Date(),
                notes: "Status updated to \(newStatus)"
            )
            
            updatedWorkOrder.items[itemIndex].statusHistory.append(newStatusEntry)
            updatedWorkOrder.items[itemIndex].lastModified = Date()
            updatedWorkOrder.items[itemIndex].lastModifiedBy = AppState.shared.currentUserName
            updatedWorkOrder.lastModified = Date()
            updatedWorkOrder.lastModifiedBy = AppState.shared.currentUserName
            
            print("🔍 DEBUG: Added status to history. Total statuses now: \(updatedWorkOrder.items[itemIndex].statusHistory.count)")
            
            print("🔍 DEBUG: Calling workOrdersDB.updateWorkOrder...")
            print("🔍 DEBUG: Work Order ID: \(updatedWorkOrder.id)")
            print("🔍 DEBUG: Work Order Number: \(updatedWorkOrder.workOrderNumber)")
            
            try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
            
            print("✅ DEBUG: Successfully updated work order in database")
            
            // Refresh the data after successful database update
            await MainActor.run {
                print("🔍 DEBUG: Refreshing data after successful status update...")
                onDataChanged?()
            }
            
        } catch {
            print("❌ DEBUG: Error updating item status: \(error)")
            print("❌ DEBUG: Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ DEBUG: NSError domain: \(nsError.domain)")
                print("❌ DEBUG: NSError code: \(nsError.code)")
                print("❌ DEBUG: NSError userInfo: \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - Update Item Status With Completion Details
    private func updateItemStatusWithCompletion(_ newStatus: String, partsUsed: String, hoursWorked: String, cost: String) async {
        print("🔍 DEBUG: updateItemStatusWithCompletion called with status: '\(newStatus)'")
        print("🔍 DEBUG: Parts: '\(partsUsed)', Hours: '\(hoursWorked)', Cost: '\(cost)'")
        
        do {
            print("🔍 DEBUG: Creating updated work order copy...")
            var updatedWorkOrder = workOrder
            
            // Update completion details
            updatedWorkOrder.items[itemIndex].partsUsed = partsUsed.isEmpty ? nil : partsUsed
            updatedWorkOrder.items[itemIndex].hoursWorked = hoursWorked.isEmpty ? nil : hoursWorked
            updatedWorkOrder.items[itemIndex].finalCost = cost.isEmpty ? nil : cost
            
            // Add new status to status history
            let newStatusEntry = WO_Status(
                status: newStatus,
                user: AppState.shared.currentUserName,
                timestamp: Date(),
                notes: "Status updated to \(newStatus) with completion details"
            )
            
            updatedWorkOrder.items[itemIndex].statusHistory.append(newStatusEntry)
            updatedWorkOrder.items[itemIndex].lastModified = Date()
            updatedWorkOrder.items[itemIndex].lastModifiedBy = AppState.shared.currentUserName
            updatedWorkOrder.lastModified = Date()
            updatedWorkOrder.lastModifiedBy = AppState.shared.currentUserName
            
            print("🔍 DEBUG: Updated completion details - Parts: '\(updatedWorkOrder.items[itemIndex].partsUsed ?? "nil")', Hours: '\(updatedWorkOrder.items[itemIndex].hoursWorked ?? "nil")', Cost: '\(updatedWorkOrder.items[itemIndex].finalCost ?? "nil")'")
            print("🔍 DEBUG: Added status to history. Total statuses now: \(updatedWorkOrder.items[itemIndex].statusHistory.count)")
            
            print("🔍 DEBUG: Calling workOrdersDB.updateWorkOrder...")
            print("🔍 DEBUG: Work Order ID: \(updatedWorkOrder.id)")
            print("🔍 DEBUG: Work Order Number: \(updatedWorkOrder.workOrderNumber)")
            
            try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
            
            print("✅ DEBUG: Successfully updated work order in database")
            
            // Refresh the data after successful database update
            await MainActor.run {
                print("🔍 DEBUG: Refreshing data after successful completion status update...")
                onDataChanged?()
            }
            
        } catch {
            print("❌ DEBUG: Error updating item status with completion: \(error)")
            print("❌ DEBUG: Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ DEBUG: NSError domain: \(nsError.domain)")
                print("❌ DEBUG: NSError code: \(nsError.code)")
                print("❌ DEBUG: NSError userInfo: \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - ItemDetailSheet
struct ItemDetailSheet: View {
    let workOrder: WorkOrder
    let item: WO_Item
    let itemIndex: Int
    
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var workOrdersDB = WorkOrdersDatabase.shared
    
    // ───── State for functionality ─────
    @State private var showStatusSelection = false
    @State private var showAddNotes = false
    @State private var showGallery = false
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL?
    
    // ───── Computed Properties ─────
    private var itemDisplayName: String {
        "\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))"
    }
    
    private var currentStatus: String {
        item.statusHistory.last?.status ?? "Checked In"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ───── Custom Navigation Header ─────
            HStack {
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("Item Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    Button("Change Status") {
                        showStatusSelection = true
                    }
                    
                    Button("Add Notes") {
                        showAddNotes = true
                    }
                    
                    Button("View Full Work Order") {
                        dismiss()
                        appState.navigateToWorkOrderDetail(workOrder)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // ───── Content ─────
            ScrollView {
                VStack(spacing: 20) {
                    // ───── Item Header Card ─────
                    itemHeaderCard
                    
                    // ───── Item Images Section ─────
                    itemImagesSection
                    
                    // ───── Item Details Section ─────
                    itemDetailsSection
                    
                    // ───── Status & Notes Section ─────
                    statusAndNotesSection
                }
                .padding()
            }
        }
        .sheet(isPresented: $showStatusSelection) {
            StatusSelectionView(
                currentStatus: currentStatus,
                onStatusSelected: { newStatus in
                    Task {
                        await updateItemStatus(newStatus)
                    }
                    showStatusSelection = false
                }
            )
        }
        .sheet(isPresented: $showAddNotes) {
            AddNotesView(
                workOrder: workOrder,
                item: item,
                itemIndex: itemIndex,
                onNotesAdded: { noteText, images in
                    Task {
                        await addItemNote(noteText, images: images)
                    }
                    showAddNotes = false
                }
            )
        }
        .sheet(isPresented: $showGallery) {
            ImageGalleryView(images: item.imageUrls, title: itemDisplayName)
        }
        .sheet(isPresented: $showImageViewer) {
            if let imageURL = selectedImageURL {
                FullScreenImageViewer(imageURL: imageURL, isPresented: $showImageViewer)
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var itemHeaderCard: some View {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(itemDisplayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            StatusBadge(status: currentStatus)
                        }
                        
                        Text(item.type)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
    }
    
    @ViewBuilder
    private var itemImagesSection: some View {
        if !item.imageUrls.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Images")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(Array(item.imageUrls.prefix(6).enumerated()), id: \.offset) { index, imageURL in
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 80)
                                .clipped()
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectedImageURL = URL(string: imageURL)
                                    showImageViewer = true
                                }
                        } placeholder: {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 80)
                                .cornerRadius(8)
                        }
                    }
                }
                
                if item.imageUrls.count > 6 {
                    Button("View All Images") {
                        showGallery = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var itemDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Item Details")
                .font(.headline)
                    
                    // ───── Customer Info ─────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Customer")
                    .font(.subheadline)
                    .fontWeight(.medium)
                        
                        Text(workOrder.customerName)
                            .font(.subheadline)
                        
                        if !workOrder.customerPhone.isEmpty {
                            HStack {
                                Text(workOrder.customerPhone)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Button(action: {
                                    if let url = URL(string: "tel:\(workOrder.customerPhone)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "phone")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
            
            // ───── Dropdown Details ─────
            if !item.dropdowns.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Specifications")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(item.dropdowns.keys.sorted()), id: \.self) { key in
                        if let value = item.dropdowns[key], !value.isEmpty {
                            HStack {
                                Text("\(key):")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(value)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
                    
                    // ───── Reasons for Service ─────
                    if !item.reasonsForService.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reasons for Service")
                        .font(.subheadline)
                        .fontWeight(.medium)
                            
                            ForEach(item.reasonsForService, id: \.self) { reason in
                                HStack(spacing: 8) {
                            Button(action: {
                                toggleReasonCompletion(reason)
                            }) {
                                    Image(systemName: item.completedReasons.contains(reason) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(item.completedReasons.contains(reason) ? .green : .secondary)
                            }
                            
                            // ───── Display reason with note for "Other" ─────
                            if reason.lowercased().contains("other") && !(item.reasonNotes?.isEmpty ?? true) {
                                Text("\(reason) • \(item.reasonNotes ?? "")")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            } else {
                                    Text(reason)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                                    
                                    Spacer()
                        }
                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
    
    @ViewBuilder
    private var statusAndNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status & Notes")
                .font(.headline)
                    
                    // ───── Status History ─────
                    if !item.statusHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status History")
                        .font(.subheadline)
                        .fontWeight(.medium)
                            
                            ForEach(item.statusHistory.reversed(), id: \.timestamp) { status in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(status.status)
                                    .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        Text("by \(status.user)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(status.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            // ───── Notes ─────
            if !item.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(item.notes.reversed(), id: \.timestamp) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.text)
                                            .font(.caption)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text("by \(note.user)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(note.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                    .font(.caption2)
                                            .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func updateItemStatus(_ newStatus: String) async {
        do {
            var updatedWorkOrder = workOrder
            updatedWorkOrder.items[itemIndex].statusHistory.append(
                WO_Status(
                    status: newStatus,
                    user: appState.currentUserName,
                    timestamp: Date(),
                    notes: nil
                )
            )
            updatedWorkOrder.items[itemIndex].lastModified = Date()
            updatedWorkOrder.items[itemIndex].lastModifiedBy = appState.currentUserName
            updatedWorkOrder.lastModified = Date()
            updatedWorkOrder.lastModifiedBy = appState.currentUserName
            
            try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
        } catch {
            print("❌ Error updating item status: \(error)")
        }
    }
    
    private func addItemNote(_ noteText: String, images: [UIImage]) async {
        do {
            var updatedWorkOrder = workOrder
            updatedWorkOrder.items[itemIndex].notes.append(
                WO_Note(
                    workOrderId: workOrder.id,
                    itemId: item.id.uuidString,
                    user: appState.currentUserName,
                    text: noteText,
                    timestamp: Date(),
                    imageUrls: []
                )
            )
            updatedWorkOrder.items[itemIndex].lastModified = Date()
            updatedWorkOrder.items[itemIndex].lastModifiedBy = appState.currentUserName
            updatedWorkOrder.lastModified = Date()
            updatedWorkOrder.lastModifiedBy = appState.currentUserName
            
            try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
        } catch {
            print("❌ Error adding item note: \(error)")
        }
    }
    
    private func toggleReasonCompletion(_ reason: String) {
        Task {
            do {
                var updatedWorkOrder = workOrder
                if updatedWorkOrder.items[itemIndex].completedReasons.contains(reason) {
                    updatedWorkOrder.items[itemIndex].completedReasons.removeAll { $0 == reason }
                } else {
                    updatedWorkOrder.items[itemIndex].completedReasons.append(reason)
                }
                updatedWorkOrder.items[itemIndex].lastModified = Date()
                updatedWorkOrder.items[itemIndex].lastModifiedBy = appState.currentUserName
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = appState.currentUserName
                
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
            } catch {
                print("❌ Error toggling reason completion: \(error)")
            }
        }
    }
}

// MARK: - FullItemDetailSheet
struct FullItemDetailSheet: View {
    let workOrder: WorkOrder
    let item: WO_Item
    let itemIndex: Int
    let onClose: () -> Void
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var workOrdersDB = WorkOrdersDatabase.shared
    
    // ───── State for functionality ─────
    @State private var showStatusSelection = false
    @State private var showAddNotes = false
    @State private var showGallery = false
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL?
    
    // ───── Computed Properties ─────
    private var itemDisplayName: String {
        "\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))"
    }
    
    private var currentStatus: String {
        item.statusHistory.last?.status ?? "Checked In"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ───── Custom Navigation Header ─────
            HStack {
                Button("Back") {
                    onClose()
                }
                .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                Text("Item Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    Button("Change Status") {
                        showStatusSelection = true
                    }
                    
                    Button("Add Notes") {
                        showAddNotes = true
                    }
                    
                    Button("View Full Work Order") {
                        onClose()
                        appState.navigateToWorkOrderDetail(workOrder)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // ───── Content ─────
            ScrollView {
                VStack(spacing: 20) {
                    // ───── Item Header Card ─────
                    itemHeaderCard
                    
                    // ───── Item Images Section ─────
                    itemImagesSection
                    
                    // ───── Item Details Section ─────
                    itemDetailsSection
                    
                    // ───── Status & Notes Section ─────
                    statusAndNotesSection
                }
                .padding()
            }
        }
        .sheet(isPresented: $showStatusSelection) {
            StatusSelectionView(
                currentStatus: currentStatus,
                onStatusSelected: { newStatus in
                    Task {
                        await updateItemStatus(newStatus)
                    }
                    showStatusSelection = false
                }
            )
        }
        .sheet(isPresented: $showAddNotes) {
            AddNotesView(
                workOrder: workOrder,
                item: item,
                itemIndex: itemIndex,
                onNotesAdded: { noteText, images in
                    Task {
                        await addItemNote(noteText, images: images)
                    }
                    showAddNotes = false
                }
            )
        }
        .sheet(isPresented: $showGallery) {
            ImageGalleryView(images: item.imageUrls, title: itemDisplayName)
        }
        .sheet(isPresented: $showImageViewer) {
            if let imageURL = selectedImageURL {
                FullScreenImageViewer(imageURL: imageURL, isPresented: $showImageViewer)
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var itemHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(itemDisplayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                StatusBadge(status: currentStatus)
            }
            
            Text(item.type)
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var itemImagesSection: some View {
        if !item.imageUrls.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Images")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(Array(item.imageUrls.prefix(6).enumerated()), id: \.offset) { index, imageURL in
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 80)
                                .clipped()
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectedImageURL = URL(string: imageURL)
                                    showImageViewer = true
                                }
                        } placeholder: {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 80)
                                .cornerRadius(8)
                        }
                    }
                }
                
                if item.imageUrls.count > 6 {
                    Button("View All Images") {
                        showGallery = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var itemDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Item Details")
                .font(.headline)
            
            // ───── Customer Info ─────
            VStack(alignment: .leading, spacing: 8) {
                Text("Customer")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(workOrder.customerName)
                    .font(.subheadline)
                
                if !workOrder.customerPhone.isEmpty {
                    HStack {
                        Text(workOrder.customerPhone)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(action: {
                            if let url = URL(string: "tel:\(workOrder.customerPhone)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Image(systemName: "phone")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // ───── Dropdown Details ─────
            if !item.dropdowns.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Specifications")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(item.dropdowns.keys.sorted()), id: \.self) { key in
                        if let value = item.dropdowns[key], !value.isEmpty {
                            HStack {
                                Text("\(key):")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                Text(value)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            
            // ───── Reasons for Service ─────
            if !item.reasonsForService.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reasons for Service")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(item.reasonsForService, id: \.self) { reason in
                        HStack(spacing: 8) {
                            Button(action: {
                                toggleReasonCompletion(reason)
                            }) {
                                Image(systemName: item.completedReasons.contains(reason) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(item.completedReasons.contains(reason) ? .green : .secondary)
                            }
                            
                            // ───── Display reason with note for "Other" ─────
                            if reason.lowercased().contains("other") && !(item.reasonNotes?.isEmpty ?? true) {
                                Text("\(reason) • \(item.reasonNotes ?? "")")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            } else {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var statusAndNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status & Notes")
                .font(.headline)
            
            // ───── Status History ─────
            if !item.statusHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status History")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(item.statusHistory.reversed(), id: \.timestamp) { status in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(status.status)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text("by \(status.user)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(status.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                    }
                    
                    // ───── Notes ─────
                    if !item.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                            
                            ForEach(item.notes.reversed(), id: \.timestamp) { note in
                                VStack(alignment: .leading, spacing: 4) {
                            Text(note.text)
                                .font(.caption)
                                .foregroundColor(.primary)
                                    
                                    HStack {
                                        Text("by \(note.user)")
                                    .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                Text(note.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                    .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                        .padding(.vertical, 2)
                    }
                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
    
    // MARK: - Actions
    
    private func updateItemStatus(_ newStatus: String) async {
        do {
            var updatedWorkOrder = workOrder
            updatedWorkOrder.items[itemIndex].statusHistory.append(
                WO_Status(
                    status: newStatus,
                    user: appState.currentUserName,
                    timestamp: Date(),
                    notes: nil
                )
            )
            updatedWorkOrder.items[itemIndex].lastModified = Date()
            updatedWorkOrder.items[itemIndex].lastModifiedBy = appState.currentUserName
            updatedWorkOrder.lastModified = Date()
            updatedWorkOrder.lastModifiedBy = appState.currentUserName
            
            try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
        } catch {
            print("❌ Error updating item status: \(error)")
        }
    }
    
    private func addItemNote(_ noteText: String, images: [UIImage]) async {
        do {
            var updatedWorkOrder = workOrder
            updatedWorkOrder.items[itemIndex].notes.append(
                WO_Note(
                    workOrderId: workOrder.id,
                    itemId: item.id.uuidString,
                    user: appState.currentUserName,
                    text: noteText,
                    timestamp: Date(),
                    imageUrls: []
                )
            )
            updatedWorkOrder.items[itemIndex].lastModified = Date()
            updatedWorkOrder.items[itemIndex].lastModifiedBy = appState.currentUserName
            updatedWorkOrder.lastModified = Date()
            updatedWorkOrder.lastModifiedBy = appState.currentUserName
            
            try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
        } catch {
            print("❌ Error adding item note: \(error)")
        }
    }
    
    private func toggleReasonCompletion(_ reason: String) {
        Task {
            do {
                var updatedWorkOrder = workOrder
                if updatedWorkOrder.items[itemIndex].completedReasons.contains(reason) {
                    updatedWorkOrder.items[itemIndex].completedReasons.removeAll { $0 == reason }
                } else {
                    updatedWorkOrder.items[itemIndex].completedReasons.append(reason)
                }
                updatedWorkOrder.items[itemIndex].lastModified = Date()
                updatedWorkOrder.items[itemIndex].lastModifiedBy = appState.currentUserName
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = appState.currentUserName
                
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
            } catch {
                print("❌ Error toggling reason completion: \(error)")
            }
        }
    }
}

// MARK: - ItemDetailSheetView
