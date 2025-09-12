//
//  MyWorkOrderItemsView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//

// ───── MY WORK ORDER ITEMS VIEW ─────
import SwiftUI

/// Shows WO_Items for the currently logged-in user, filtered by status (excluding "Checked In")
/// Filters: statusHistory.status != "Checked In" && statusHistory.user == currentUser.displayName
struct MyWorkOrderItemsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var workOrdersDB = WorkOrdersDatabase.shared
    @State private var filteredItemData: [WorkOrderItemData] = []
    @State private var isLoading = true
    @State private var showItemDetailSheet = false
    @State private var itemDataForSheet: WorkOrderItemData?
    @State private var sheetItemData: WorkOrderItemData?
    @State private var capturedItemData: WorkOrderItemData?
    @State private var displayItemData: WorkOrderItemData?

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
                    ForEach(filteredItemData) { itemData in
                        MyWorkOrderItemCard(
                            item: itemData.item,
                            workOrder: itemData.workOrder,
                            itemIndex: itemData.itemIndex,
                            onTap: {
                                print("🔍 DEBUG: Tapped on item: \(itemData.workOrder.workOrderNumber)-\(String(format: "%03d", itemData.itemIndex + 1))")
                                print("🔍 DEBUG: Capturing itemData: \(itemData.workOrder.workOrderNumber)")
                                
                                // Capture the data immediately
                                capturedItemData = itemData
                                itemDataForSheet = itemData
                                sheetItemData = itemData
                                
                                print("🔍 DEBUG: capturedItemData is now: \(capturedItemData?.workOrder.workOrderNumber ?? "nil")")
                                print("🔍 DEBUG: itemDataForSheet is now: \(itemDataForSheet?.workOrder.workOrderNumber ?? "nil")")
                                print("🔍 DEBUG: sheetItemData is now: \(sheetItemData?.workOrder.workOrderNumber ?? "nil")")
                                
                                // Use a small delay to ensure state is set before presenting sheet
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showItemDetailSheet = true
                                    print("🔍 DEBUG: showItemDetailSheet set to: \(showItemDetailSheet)")
                                }
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
        .fullScreenCover(isPresented: $showItemDetailSheet) {
            VStack {
                Text("Item Details")
                    .font(.title)
                    .padding()
                
                if let itemData = displayItemData {
                    Text("Work Order: \(itemData.workOrder.workOrderNumber)")
                        .font(.headline)
                        .padding()
                    
                    Text("Item: \(itemData.item.type)")
                        .font(.subheadline)
                        .padding()
                    
                    Text("Customer: \(itemData.workOrder.customerName)")
                        .font(.subheadline)
                        .padding()
                    
                    // ───── Reasons for Service ─────
                    if !itemData.item.reasonsForService.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reasons for Service")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(itemData.item.reasonsForService, id: \.self) { reason in
                                HStack(spacing: 8) {
                                    Image(systemName: itemData.item.completedReasons.contains(reason) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(itemData.item.completedReasons.contains(reason) ? .green : .secondary)
                                    
                                    // ───── Display reason with note for "Other" ─────
                                    if reason.lowercased().contains("other") && !(itemData.item.reasonNotes?.isEmpty ?? true) {
                                        Text("\(reason) • \(itemData.item.reasonNotes ?? "")")
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
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // ───── Status History ─────
                    if !itemData.item.statusHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status History")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(itemData.item.statusHistory.reversed(), id: \.timestamp) { status in
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
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    Text("Debug: displayItemData is available")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding()
                } else {
                    Text("Work Order: UNKNOWN")
                        .font(.headline)
                        .padding()
                    
                    Text("Item: UNKNOWN")
                        .font(.subheadline)
                        .padding()
                    
                    Text("Customer: UNKNOWN")
                        .font(.subheadline)
                        .padding()
                    
                    Text("Debug: displayItemData is nil")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Button("Close") {
                    showItemDetailSheet = false
                    itemDataForSheet = nil
                    sheetItemData = nil
                    capturedItemData = nil
                    displayItemData = nil
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .onAppear {
                print("🔍 DEBUG: Sheet appeared, capturedItemData is: \(capturedItemData?.workOrder.workOrderNumber ?? "nil")")
                print("🔍 DEBUG: Sheet appeared, itemDataForSheet is: \(itemDataForSheet?.workOrder.workOrderNumber ?? "nil")")
                print("🔍 DEBUG: Sheet appeared, sheetItemData is: \(sheetItemData?.workOrder.workOrderNumber ?? "nil")")
                
                // Set displayItemData from any available source
                if let data = capturedItemData {
                    displayItemData = data
                    print("🔍 DEBUG: Set displayItemData from capturedItemData: \(data.workOrder.workOrderNumber)")
                } else if let data = itemDataForSheet {
                    displayItemData = data
                    print("🔍 DEBUG: Set displayItemData from itemDataForSheet: \(data.workOrder.workOrderNumber)")
                } else if let data = sheetItemData {
                    displayItemData = data
                    print("🔍 DEBUG: Set displayItemData from sheetItemData: \(data.workOrder.workOrderNumber)")
                } else {
                    print("🔍 DEBUG: No data available to set displayItemData")
                }
            }
        }
        // END
    }

    // MARK: - Private Methods

    private func loadFilteredItems() {
        isLoading = true
        
        Task {
            do {
                // Fetch all work orders from database
                let allWorkOrders = try await workOrdersDB.getAllWorkOrders()
                
                // Filter to active work orders only
                let activeWorkOrders = allWorkOrders.filter { workOrder in
                    !workOrder.isDeleted && workOrder.status.lowercased() != "closed"
                }
                
                // Extract items where current user has made status/note updates (excluding "Checked In")
                var itemDataArray: [WorkOrderItemData] = []
                
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
                        
                        // Include if user has made any status updates or notes
                        if !userStatusUpdates.isEmpty || !userNotes.isEmpty {
                            itemDataArray.append(WorkOrderItemData(
                                item: item,
                                workOrder: workOrder,
                                itemIndex: itemIndex
                            ))
                        }
                    }
                }
                
                // Sort by most recent activity (status updates or notes)
                itemDataArray.sort { data1, data2 in
                    let latest1 = getLatestActivityTimestamp(for: data1.item)
                    let latest2 = getLatestActivityTimestamp(for: data2.item)
                    return latest1 > latest2
                }
                
                await MainActor.run {
                    self.filteredItemData = itemDataArray
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
}

// MARK: - Data Structure
struct WorkOrderItemData: Identifiable {
    let id = UUID()
    let item: WO_Item
    let workOrder: WorkOrder
    let itemIndex: Int
}

// MARK: - Custom Item Card for My Work Orders
struct MyWorkOrderItemCard: View {
    let item: WO_Item
    let workOrder: WorkOrder
    let itemIndex: Int
    let onTap: () -> Void
    
    @State private var partsUsedText: String = ""
    @State private var isEditingParts: Bool = false
    @State private var isSavingParts: Bool = false
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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // ───── Header Row ─────
                HStack {
                    // Work Order Number
                    Text("\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Status Badge
                    StatusBadge(status: currentStatus)
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
                        
                        ForEach(item.reasonsForService, id: \.self) { reason in
                            HStack(spacing: 8) {
                                Image(systemName: item.completedReasons.contains(reason) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(item.completedReasons.contains(reason) ? .green : .secondary)
                                    .font(.caption)
                                
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
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .onAppear {
            // Initialize parts used text from item
            partsUsedText = item.partsUsed ?? ""
        }
    }
    
    // MARK: - Parts Used Section
    @ViewBuilder
    private var partsUsedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Parts Used")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isEditingParts {
                    Button("Cancel") {
                        // Reset to original value and stop editing
                        partsUsedText = item.partsUsed ?? ""
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
                    TextField("Enter parts used...", text: $partsUsedText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(2...4)
                        .font(.caption)
                    
                    HStack {
                        Button("Save") {
                            savePartsUsed()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .disabled(isSavingParts || partsUsedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        if isSavingParts {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Spacer()
                    }
                }
            } else {
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
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Save Parts Used
    private func savePartsUsed() {
        guard !partsUsedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSavingParts = true
        
        Task {
            do {
                // Create a copy of the work order with updated parts used
                var updatedWorkOrder = workOrder
                updatedWorkOrder.items[itemIndex].partsUsed = partsUsedText.trimmingCharacters(in: .whitespacesAndNewlines)
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
                print("❌ Error saving parts used: \(error)")
                await MainActor.run {
                    isSavingParts = false
                }
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


// ───── PREVIEW ─────
#Preview {
    let appState = AppState.previewLoggedIn(role: .tech)
    MyWorkOrderItemsView()
        .environmentObject(appState)
}
// END