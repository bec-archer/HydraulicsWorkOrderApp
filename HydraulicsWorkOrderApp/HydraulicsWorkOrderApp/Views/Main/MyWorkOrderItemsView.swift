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
                    ForEach(filteredItemData) { itemData in
                        MyWorkOrderItemCard(
                            item: itemData.item,
                            workOrder: itemData.workOrder,
                            itemIndex: itemData.itemIndex,
                            onTap: {
                                print("🔍 DEBUG: Tapped on item: \(itemData.workOrder.workOrderNumber)-\(String(format: "%03d", itemData.itemIndex + 1))")
                                print("🔍 DEBUG: Setting selectedItemForSheet: \(itemData.workOrder.workOrderNumber)")
                                
                                // Set the selected item for the sheet
                                selectedItemForSheet = itemData
                                
                                print("🔍 DEBUG: selectedItemForSheet is now: \(selectedItemForSheet?.workOrder.workOrderNumber ?? "nil")")
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
        .sheet(item: $selectedItemForSheet) { itemData in
            ItemDetailSheetView(
                workOrder: itemData.workOrder,
                item: itemData.item,
                itemIndex: itemData.itemIndex
            ) {
                selectedItemForSheet = nil
                // Refresh the data when sheet is dismissed
                loadFilteredItems()
            }
            .environmentObject(appState)
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

// MARK: - ItemDetailSheetView
struct ItemDetailSheetView: View {
    let workOrder: WorkOrder
    let item: WO_Item
    let itemIndex: Int
    let onClose: () -> Void
    
    @EnvironmentObject var appState: AppState
    @StateObject private var workOrdersDB = WorkOrdersDatabase.shared
    @State private var currentWorkOrder: WorkOrder
    @State private var currentItem: WO_Item
    
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL?
    @State private var showGallery = false
    @State private var showStatusSelection = false
    @State private var showAddNotes = false
    
    init(workOrder: WorkOrder, item: WO_Item, itemIndex: Int, onClose: @escaping () -> Void) {
        self.workOrder = workOrder
        self.item = item
        self.itemIndex = itemIndex
        self.onClose = onClose
        self._currentWorkOrder = State(initialValue: workOrder)
        self._currentItem = State(initialValue: item)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Header row: Composite item number • Reasons (checkboxes) • StatusBadge
                    HStack(alignment: .top, spacing: 12) {
                        // Left: Composite WO_Number-ItemIndex (e.g., 250826-001-003)
                        Text("\(currentWorkOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
                            .font(.headline)
                            .foregroundColor(ThemeManager.shared.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        
                        Spacer(minLength: 8)
                        
                        // Middle: Reasons for Service (chosen at intake) — check to log "Service Performed — <Reason>"
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(currentItem.reasonsForService, id: \.self) { reason in
                                HStack(spacing: 8) {
                                    Button(action: {
                                        toggleReasonCompletion(reason)
                                    }) {
                                        Image(systemName: isReasonPerformed(reason) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(isReasonPerformed(reason) ? .green : ThemeManager.shared.textSecondary)
                                    }
                                    
                                    // ───── Display reason with note for "Other" ─────
                                    if reason.lowercased().contains("other") && !(currentItem.reasonNotes?.isEmpty ?? true) {
                                        Text("\(reason) • \(currentItem.reasonNotes ?? "")")
                                .font(.subheadline)
                                            .foregroundColor(ThemeManager.shared.textPrimary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.9)
                                    } else {
                                        Text(reason)
                                .font(.subheadline)
                                            .foregroundColor(ThemeManager.shared.textPrimary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.9)
                                    }
                                }
                            }
                        }
                        
                        // Right: StatusBadge (tappable) and Add Notes button
                        HStack(spacing: 8) {
                            Button(action: {
                                showStatusSelection = true
                            }) {
                                StatusBadge(status: getActualItemStatus(currentItem))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                showAddNotes = true
                            }) {
                                Image(systemName: "note.text.badge.plus")
                                    .foregroundColor(ThemeManager.shared.linkColor)
                                    .font(.title3)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Type line
                    Text(currentItem.type.isEmpty ? "Item" : currentItem.type)
                            .font(.subheadline)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // Size / Color / Machine / Brand / Wait summary (muted), with inline "Other" note if present
                    if !summaryLineForItem(currentItem).isEmpty {
                        Text(summaryLineForItem(currentItem))
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    
                    // Main body split: Left (images) + Right (notes & status)
                    HStack(alignment: .top, spacing: 16) {
                        // Left: Primary image (large, 1:1) + responsive 2×2 thumbnails beneath
                        VStack(spacing: 8) {
                            // Use a fixed size that allows cards to expand
                            let primarySize: CGFloat = 300
                            let gridSpacing: CGFloat = 8
                            let thumbSize = (primarySize - gridSpacing) / 2.0
                            
                            VStack(spacing: 8) {
                                // PRIMARY 1:1 image
                                if let firstImageURL = currentItem.imageUrls.first {
                                    AsyncImage(url: URL(string: firstImageURL)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill() // crop, do not stretch
                                            .frame(width: primarySize, height: primarySize)
                                            .clipped()
                                            .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                                            .onTapGesture { 
                                                selectedImageURL = URL(string: firstImageURL)
                                                showImageViewer = true
                                            }
                                    } placeholder: {
                                        Rectangle()
                                            .fill(ThemeManager.shared.border.opacity(0.3))
                                            .frame(width: primarySize, height: primarySize)
                                            .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                    }
                } else {
                                    // No images: placeholder primary
                                    Rectangle()
                                        .fill(ThemeManager.shared.border.opacity(0.2))
                                        .frame(width: primarySize, height: primarySize)
                                        .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.system(size: primarySize * 0.12, weight: .regular))
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                        )
                                }
                                
                                // 2×2 thumbnails directly beneath primary (images 2,3,4, +Qty)
                                if currentItem.imageUrls.count > 1 {
                                    let extras = Array(currentItem.imageUrls.dropFirst())
                                    LazyVGrid(
                                        columns: [
                                            GridItem(.fixed(thumbSize), spacing: gridSpacing),
                                            GridItem(.fixed(thumbSize), spacing: gridSpacing)
                                        ],
                                        spacing: gridSpacing
                                    ) {
                                        ForEach(Array(extras.prefix(3).enumerated()), id: \.offset) { _, imageURL in
                                            AsyncImage(url: URL(string: imageURL)) { img in
                                                img.resizable()
                                                    .scaledToFill()
                                                    .frame(width: thumbSize, height: thumbSize)
                                                    .clipped()
                                                    .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                                    .onTapGesture { 
                                                        selectedImageURL = URL(string: imageURL)
                                                        showImageViewer = true
                                                    }
                                            } placeholder: {
                                                Rectangle()
                                                    .fill(ThemeManager.shared.border.opacity(0.3))
                                                    .frame(width: thumbSize, height: thumbSize)
                                                    .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                            }
                                        }
                                        
                                        // +Qty tile if there are 6 or more total images
                                        if currentItem.imageUrls.count >= 6 {
                                            Button(action: {
                                                // Show gallery for all images
                                                showGallery = true
                                            }) {
                                                ZStack {
                                                    // Show the 5th image (index 4) as background
                                                    AsyncImage(url: URL(string: currentItem.imageUrls[4])) { image in
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: thumbSize, height: thumbSize)
                                                            .clipped()
                                                            .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                                    } placeholder: {
                                                        Rectangle()
                                                            .fill(ThemeManager.shared.border.opacity(0.3))
                                                            .frame(width: thumbSize, height: thumbSize)
                                                            .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                                    }
                                                    
                                                    // Dark overlay
                                                    Rectangle()
                                                        .fill(Color.black.opacity(0.6))
                                                        .frame(width: thumbSize, height: thumbSize)
                                                        .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                                    
                                                    // +Qty text
                                                    Text("+\(currentItem.imageUrls.count - 4)")
                                                        .font(.headline)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .frame(width: primarySize, alignment: .leading) // grid width matches primary
                                }
                            }
                        }
                        
                        // Right: Notes & Status timeline
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes & Status")
                        .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(ThemeManager.shared.textPrimary)
                            
                            // Unified timeline: notes and status history chronologically
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(getCombinedTimeline(), id: \.id) { timelineItem in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(ThemeManager.shared.textSecondary)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            timelineItem.content
                                            
                                            HStack {
                                                Text(timelineItem.user)
                                                    .font(.system(size: 10 * 1.2))
                                                    .foregroundColor(ThemeManager.shared.textSecondary)
                                                
                                                Text("•")
                                                    .font(.system(size: 10 * 1.2))
                                                    .foregroundColor(ThemeManager.shared.textSecondary)
                                                
                                                Text(timelineItem.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                                    .font(.system(size: 10 * 1.2))
                                                    .foregroundColor(ThemeManager.shared.textSecondary)
                                            }
                                            
                                            Spacer()
                                        }
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(16)
                .background(ThemeManager.shared.cardBackground)
                .cornerRadius(ThemeManager.shared.cardCornerRadius)
                .shadow(
                    color: ThemeManager.shared.cardShadowColor.opacity(ThemeManager.shared.cardShadowOpacity),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onClose()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showGallery) {
            ImageGalleryView(images: currentItem.imageUrls, title: "\(currentWorkOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
        }
        .fullScreenCover(isPresented: $showStatusSelection) {
            StatusSelectionView(
                currentStatus: currentItem.statusHistory.last?.status ?? "Checked In",
                onStatusSelected: { newStatus in
                    updateItemStatus(newStatus)
                    showStatusSelection = false
                }
            )
        }
        .fullScreenCover(isPresented: $showAddNotes) {
            AddNotesView(
                workOrder: currentWorkOrder,
                item: currentItem,
                itemIndex: itemIndex,
                onNotesAdded: { noteText, images in
                    addItemNote(noteText, images: images)
                    showAddNotes = false
                }
            )
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let imageURL = selectedImageURL {
                FullScreenImageViewer(imageURL: imageURL, isPresented: $showImageViewer)
            } else {
                Text("No image selected")
            }
        }
    }
    
    // MARK: - Helper Functions
    func isReasonPerformed(_ reason: String) -> Bool {
        return currentItem.completedReasons.contains(reason)
    }
    
    func getActualItemStatus(_ item: WO_Item) -> String {
        // Find the last status that is NOT a "Service Performed" entry
        let actualStatuses = item.statusHistory.filter { !$0.status.hasPrefix("Service Performed") }
        return actualStatuses.last?.status ?? "Checked In"
    }
    
    func summaryLineForItem(_ item: WO_Item) -> String {
        var components: [String] = []
        
        if let size = item.dropdowns["Size"], !size.isEmpty {
            components.append("Size: \(size)")
        }
        if let color = item.dropdowns["Color"], !color.isEmpty {
            components.append("Color: \(color)")
        }
        if let machine = item.dropdowns["Machine"], !machine.isEmpty {
            components.append("Machine: \(machine)")
        }
        if let brand = item.dropdowns["Brand"], !brand.isEmpty {
            components.append("Brand: \(brand)")
        }
        
        return components.joined(separator: " • ")
    }
    
    // MARK: - Data Refresh
    private func refreshData() {
        Task {
            do {
                let latestWorkOrder = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorkOrder, Error>) in
                    workOrdersDB.fetchWorkOrder(woId: workOrder.id) { result in
                        switch result {
                        case .success(let workOrder):
                            continuation.resume(returning: workOrder)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                await MainActor.run {
                    currentWorkOrder = latestWorkOrder
                    currentItem = latestWorkOrder.items[itemIndex]
                }
            } catch {
                print("❌ Error refreshing data: \(error)")
            }
        }
    }
    
    // MARK: - Timeline Item Structure
    struct TimelineItem: Identifiable {
        let id: UUID
        let timestamp: Date
        let user: String
        let content: AnyView
        let type: TimelineItemType
        
        enum TimelineItemType {
            case note
            case status
        }
    }
    
    func getCombinedTimeline() -> [TimelineItem] {
        var timelineItems: [TimelineItem] = []
        
        // Add notes
        for note in currentItem.notes {
            timelineItems.append(TimelineItem(
                id: note.id,
                timestamp: note.timestamp,
                user: note.user,
                content: AnyView(
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text)
                            .font(.system(size: 12 * 1.2))
                            .foregroundColor(ThemeManager.shared.textPrimary)
                        
                        if !note.imageUrls.isEmpty {
                            Text("\(note.imageUrls.count) image\(note.imageUrls.count == 1 ? "" : "s") attached")
                                .font(.system(size: 10 * 1.2))
                                .foregroundColor(ThemeManager.shared.textSecondary)
                        }
                    }
                ),
                type: .note
            ))
        }
        
        // Add status history
        for status in currentItem.statusHistory {
            timelineItems.append(TimelineItem(
                id: UUID(),
                timestamp: status.timestamp,
                user: status.user,
                content: AnyView(
                    Text("Status changed to: \(status.status)")
                        .font(.system(size: 12 * 1.2, weight: .medium))
                        .foregroundColor(ThemeManager.shared.textPrimary)
                ),
                type: .status
            ))
        }
        
        // Sort by timestamp (newest first)
        return timelineItems.sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Actions
    private func updateItemStatus(_ newStatus: String) {
        Task {
            do {
                // Fetch the latest work order from the database
                let latestWorkOrder = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorkOrder, Error>) in
                    workOrdersDB.fetchWorkOrder(woId: workOrder.id) { result in
                        switch result {
                        case .success(let workOrder):
                            continuation.resume(returning: workOrder)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                var updatedWorkOrder = latestWorkOrder
                
                let status = WO_Status(
                    status: newStatus,
                    user: appState.currentUserName,
                    timestamp: Date()
                )
                
                updatedWorkOrder.items[itemIndex].statusHistory.append(status)
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = appState.currentUserName
                
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
                
                // Refresh the data to show the updated status
                await MainActor.run {
                    refreshData()
                }
            } catch {
                print("❌ Error updating item status: \(error)")
            }
        }
    }
    
    private func addItemNote(_ noteText: String, images: [UIImage]) {
        Task {
            do {
                // Fetch the latest work order from the database
                let latestWorkOrder = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorkOrder, Error>) in
                    workOrdersDB.fetchWorkOrder(woId: workOrder.id) { result in
                        switch result {
                        case .success(let workOrder):
                            continuation.resume(returning: workOrder)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                var updatedWorkOrder = latestWorkOrder
                
                let note = WO_Note(
                    workOrderId: workOrder.id,
                    itemId: item.id.uuidString,
                    user: appState.currentUserName,
                    text: noteText,
                    timestamp: Date(),
                    imageUrls: [] // Images will be uploaded separately
                )
                
                updatedWorkOrder.items[itemIndex].notes.append(note)
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = appState.currentUserName
                
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
                
                // Refresh the data to show the new note
                await MainActor.run {
                    refreshData()
                }
            } catch {
                print("❌ Error adding item note: \(error)")
            }
        }
    }
    
    private func toggleReasonCompletion(_ reason: String) {
        Task {
            do {
                // Fetch the latest work order from the database
                let latestWorkOrder = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorkOrder, Error>) in
                    workOrdersDB.fetchWorkOrder(woId: workOrder.id) { result in
                        switch result {
                        case .success(let workOrder):
                            continuation.resume(returning: workOrder)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                var updatedWorkOrder = latestWorkOrder
                
                if updatedWorkOrder.items[itemIndex].completedReasons.contains(reason) {
                    updatedWorkOrder.items[itemIndex].completedReasons.removeAll { $0 == reason }
                } else {
                    updatedWorkOrder.items[itemIndex].completedReasons.append(reason)
                }
                
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = appState.currentUserName
                
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
                
                // Refresh the data to show the updated reason completion
                await MainActor.run {
                    refreshData()
                }
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