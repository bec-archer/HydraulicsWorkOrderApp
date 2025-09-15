import SwiftUI
import Foundation

// MARK: - ItemDetailSheetView
struct ItemDetailSheetView: View {
    let workOrder: WorkOrder
    let item: WO_Item
    let itemIndex: Int
    let onClose: () -> Void
    
    @EnvironmentObject var appState: AppState
    @StateObject private var workOrdersDB = WorkOrdersDatabase.shared
    
    // Simplified state management
    @State private var currentWorkOrder: WorkOrder
    @State private var currentItem: WO_Item
    @State private var isUpdating = false
    @State private var hasAppeared = false
    
    // UI state
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
    
    // Get the latest item data from the database
    private var latestItem: WO_Item {
        if let latestWorkOrder = workOrdersDB.workOrders.first(where: { $0.id == currentWorkOrder.id }),
           let foundItem = latestWorkOrder.items.first(where: { $0.id == currentItem.id }) {
            return foundItem
        }
        return currentItem
    }
    
    // Refresh data from database
    private func refreshData() {
        print("🔍 DEBUG: refreshData called")
        
        // Use the local workOrders array instead of fetching from Firebase
        if let latestWorkOrder = workOrdersDB.workOrders.first(where: { $0.id == workOrder.id }) {
            print("🔍 DEBUG: Found latest work order: \(latestWorkOrder.workOrderNumber)")
            
            // Only update if the data has actually changed to prevent infinite loops
            if currentWorkOrder.id != latestWorkOrder.id || currentWorkOrder.lastModified != latestWorkOrder.lastModified {
                currentWorkOrder = latestWorkOrder
                if itemIndex < latestWorkOrder.items.count {
                    let newItem = latestWorkOrder.items[itemIndex]
                    currentItem = newItem
                    print("🔍 DEBUG: Updated currentItem - status: \(newItem.statusHistory.last?.status ?? "none")")
                    print("🔍 DEBUG: Current item status history count: \(newItem.statusHistory.count)")
                    print("🔍 DEBUG: Current item notes count: \(newItem.notes.count)")
                }
            } else {
                print("🔍 DEBUG: No changes detected, skipping update")
            }
        } else {
            print("🔍 DEBUG: Could not find work order in local database")
        }
    }
    
    // MARK: - View Components
    
    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: Composite WO_Number-ItemIndex (e.g., 250826-001-003)
            Text("\(currentWorkOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeManager.shared.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // Middle: Reasons for Service (chosen at intake) — check to log "Service Performed — <Reason>"
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(latestItem.reasonsForService.enumerated()), id: \.element) { index, reason in
                    HStack(spacing: 8) {
                        Button(action: {
                            print("🔍 DEBUG: Reason button tapped for '\(reason)' (index: \(index))")
                            print("🔍 DEBUG: isUpdating when reason button tapped: \(isUpdating)")
                            print("🔍 DEBUG: Button action executing for reason: \(reason)")
                            toggleReasonCompletion(reason)
                        }) {
                            Image(systemName: isReasonPerformed(reason) ? "checkmark.square.fill" : "square")
                                .foregroundColor(isReasonPerformed(reason) ? .green : ThemeManager.shared.textSecondary)
                                .background(Color.red.opacity(0.1)) // Visual debug - red background
                        }
                        .disabled(isUpdating)
                        .onTapGesture {
                            print("🔍 DEBUG: Reason button onTapGesture triggered for '\(reason)' (index: \(index))")
                        }
                        
                        // ───── Display reason with note for "Other" ─────
                        if reason.lowercased().contains("other") && !(latestItem.reasonNotes?.isEmpty ?? true) {
                            Text("\(reason) • \(latestItem.reasonNotes ?? "")")
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
            VStack(spacing: 8) {
                Button(action: {
                    print("🔍 DEBUG: Status button tapped - setting showStatusSelection to true")
                    print("🔍 DEBUG: isUpdating when status button tapped: \(isUpdating)")
                    print("🔍 DEBUG: Status button action executing")
                    showStatusSelection = true
                    print("🔍 DEBUG: showStatusSelection is now: \(showStatusSelection)")
                }) {
                    StatusBadge(status: getActualItemStatus(latestItem))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isUpdating)
                .onTapGesture {
                    print("🔍 DEBUG: Status button onTapGesture triggered")
                }
                .overlay(
                    isUpdating ? 
                    ProgressView()
                        .scaleEffect(0.8)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                    : nil
                )
                
                Button(action: {
                    print("🔍 DEBUG: Add Notes button tapped")
                    print("🔍 DEBUG: isUpdating: \(isUpdating)")
                    print("🔍 DEBUG: showAddNotes before: \(showAddNotes)")
                    print("🔍 DEBUG: Add Notes button action executing")
                    showAddNotes = true
                    print("🔍 DEBUG: showAddNotes after: \(showAddNotes)")
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "note.text.badge.plus")
                            .foregroundColor(ThemeManager.shared.linkColor)
                            .font(.title3)
                        Text("Add Note")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.linkColor)
                    }
                    .frame(width: 60, height: 50)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(isUpdating)
                .buttonStyle(PlainButtonStyle())
                .onTapGesture {
                    print("🔍 DEBUG: Add Notes button onTapGesture triggered")
                }
            }
        }
    }
    
    private var itemDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Type line
            Text(latestItem.type.isEmpty ? "Item" : latestItem.type)
                .font(.subheadline)
                .foregroundColor(ThemeManager.shared.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            // Size / Color / Machine / Brand / Wait summary (muted), with inline "Other" note if present
            if !summaryLineForItem(latestItem).isEmpty {
                Text(summaryLineForItem(latestItem))
                    .font(.caption)
                    .foregroundColor(ThemeManager.shared.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
    
    private var mainBody: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: Primary image (large, 1:1) + responsive 2×2 thumbnails beneath
            VStack(spacing: 8) {
                // Use a fixed size that allows cards to expand
                let primarySize: CGFloat = 300
                let gridSpacing: CGFloat = 8
                let thumbSize = (primarySize - gridSpacing) / 2.0
                
                VStack(spacing: 8) {
                    // PRIMARY 1:1 image
                    if let firstImageURL = latestItem.imageUrls.first {
                        AsyncImage(url: URL(string: firstImageURL)) { image in
                            image
                                .resizable()
                                .scaledToFill() // crop, do not stretch
                                .frame(width: primarySize, height: primarySize)
                                .clipped()
                                .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                                .onTapGesture { 
                                    print("🔍 DEBUG: Primary image tapped: \(firstImageURL)")
                                    selectedImageURL = URL(string: firstImageURL)
                                    print("🔍 DEBUG: selectedImageURL set to: \(selectedImageURL?.absoluteString ?? "nil")")
                                    showImageViewer = true
                                    print("🔍 DEBUG: showImageViewer set to: \(showImageViewer)")
                                }
                        } placeholder: {
                            Rectangle()
                                .fill(ThemeManager.shared.border.opacity(0.3))
                                .frame(width: primarySize, height: primarySize)
                                .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                        }
                    } else {
                        Rectangle()
                            .fill(ThemeManager.shared.border.opacity(0.3))
                            .frame(width: primarySize, height: primarySize)
                            .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                    }
                    
                    // 2×2 THUMBNAIL GRID
                    if latestItem.imageUrls.count > 1 {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(thumbSize), spacing: gridSpacing), count: 2), spacing: gridSpacing) {
                            ForEach(Array(latestItem.imageUrls.dropFirst().enumerated()), id: \.offset) { index, imageURL in
                                AsyncImage(url: URL(string: imageURL)) { img in
                                    img.resizable()
                                        .scaledToFill()
                                        .frame(width: thumbSize, height: thumbSize)
                                        .clipped()
                                        .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                        .onTapGesture { 
                                            print("🔍 DEBUG: Image tapped: \(imageURL)")
                                            selectedImageURL = URL(string: imageURL)
                                            print("🔍 DEBUG: selectedImageURL set to: \(selectedImageURL?.absoluteString ?? "nil")")
                                            showImageViewer = true
                                            print("🔍 DEBUG: showImageViewer set to: \(showImageViewer)")
                                        }
                                } placeholder: {
                                    Rectangle()
                                        .fill(ThemeManager.shared.border.opacity(0.3))
                                        .frame(width: thumbSize, height: thumbSize)
                                        .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                }
                            }
                        }
                    }
                }
            }
            
            // Right: Notes & Status
            VStack(alignment: .leading, spacing: 12) {
                // ───── Notes ─────
                if !latestItem.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(latestItem.notes.reversed(), id: \.timestamp) { note in
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
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                SwiftUI.VStack(alignment: .leading, spacing: 12) {
                    // Header row: Composite item number • Reasons (checkboxes) • StatusBadge
                    headerRow
                    
                    // Item details
                    itemDetails
                    
                    // Main body split: Left (images) + Right (notes & status)
                    mainBody
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
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        print("🔍 DEBUG: Close button tapped")
                        onClose()
                    }
                }
            }
        }
        .trackUserInteraction() // Track user interactions to prevent inactivity logout
        .onAppear {
            print("🔍 DEBUG: ItemDetailSheetView onAppear")
            print("🔍 DEBUG: Currently viewing work order: \(workOrder.workOrderNumber)")
            print("🔍 DEBUG: Currently viewing item index: \(itemIndex)")
            print("🔍 DEBUG: Currently viewing item type: \(item.type)")
            print("🔍 DEBUG: Item reasons for service: \(item.reasonsForService)")
            print("🔍 DEBUG: isUpdating before reset: \(isUpdating)")
            isUpdating = false // Reset updating state
            print("🔍 DEBUG: isUpdating reset to false on appear")
            print("🔍 DEBUG: isUpdating after reset: \(isUpdating)")
            
            // Prevent infinite loops by only refreshing on first appear
            if !hasAppeared {
                hasAppeared = true
                refreshData()
            }
        }
        .onDisappear {
            print("🔍 DEBUG: ItemDetailSheetView onDisappear")
            print("🔍 DEBUG: Closing work order: \(workOrder.workOrderNumber)")
            print("🔍 DEBUG: Closing item index: \(itemIndex)")
            isUpdating = false // Reset updating state
            hasAppeared = false // Reset appear flag
            print("🔍 DEBUG: isUpdating reset to false on disappear")
        }
        .fullScreenCover(isPresented: $showGallery) {
            ImageGalleryView(images: latestItem.imageUrls, title: "\(currentWorkOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
        }
        .fullScreenCover(isPresented: $showStatusSelection) {
            StatusSelectionView(
                currentStatus: getActualItemStatus(latestItem),
                onStatusSelected: { newStatus in
                    print("🔍 DEBUG: ItemDetailSheetView - Status selected: \(newStatus)")
                    updateItemStatus(newStatus)
                    showStatusSelection = false
                    print("🔍 DEBUG: ItemDetailSheetView - Status selection sheet dismissed")
                }
            )
        }
        .fullScreenCover(isPresented: $showAddNotes) {
            SimpleAddNotesView(
                onNotesAdded: { noteText, images in
                    addItemNote(noteText, images: images)
                    showAddNotes = false
                    // Force refresh to show the new note immediately
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        refreshData()
                    }
                }
            )
            .onDisappear {
                print("🔍 DEBUG: Add Notes sheet dismissed, refreshing data")
                refreshData()
            }
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let imageURL = selectedImageURL {
                FullScreenImageViewer(imageURL: imageURL, isPresented: $showImageViewer)
                    .onAppear {
                        print("🔍 DEBUG: FullScreenImageViewer showing image: \(imageURL)")
                        print("🔍 DEBUG: selectedImageURL in onAppear: \(selectedImageURL?.absoluteString ?? "nil")")
                    }
                    .onDisappear {
                        print("🔍 DEBUG: FullScreenImageViewer dismissed")
                        print("🔍 DEBUG: selectedImageURL before reset: \(selectedImageURL?.absoluteString ?? "nil")")
                        selectedImageURL = nil
                    }
            } else {
                VStack {
                    Text("No image selected")
                        .foregroundColor(.white)
                        .font(.headline)
                    Button("Close") {
                        showImageViewer = false
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
                .onAppear {
                    print("🔍 DEBUG: FullScreenImageViewer - selectedImageURL is nil")
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    func isReasonPerformed(_ reason: String) -> Bool {
        return latestItem.completedReasons.contains(reason)
    }
    
    func getActualItemStatus(_ item: WO_Item) -> String {
        return item.statusHistory.last?.status ?? "Checked In"
    }
    
    func summaryLineForItem(_ item: WO_Item) -> String {
        var components: [String] = []
        
        // Use dropdown values instead of direct properties
        if let size = item.dropdowns["Size"], !size.isEmpty { components.append(size) }
        if let color = item.dropdowns["Color"], !color.isEmpty { components.append(color) }
        if let machine = item.dropdowns["Machine"], !machine.isEmpty { components.append(machine) }
        if let brand = item.dropdowns["Brand"], !brand.isEmpty { components.append(brand) }
        if let wait = item.dropdowns["Wait"], !wait.isEmpty { components.append("Wait: \(wait)") }
        
        return components.joined(separator: " • ")
    }
    
    // MARK: - Actions
    
    private func toggleReasonCompletion(_ reason: String) {
        guard !isUpdating else { return }
        
        // Track user interaction to reset inactivity timer
        InactivityManager.trackUserInteraction()
        
        Task {
            await MainActor.run { 
                isUpdating = true
            }
            
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
                
                // Add a small delay to ensure the database update is reflected
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                // Refresh data after successful update
                await MainActor.run {
                    refreshData()
                }
            } catch {
                print("❌ Error toggling reason completion: \(error)")
            }
            
            await MainActor.run {
                isUpdating = false
                print("🔍 DEBUG: isUpdating reset to false")
            }
        }
    }
    
    private func updateItemStatus(_ newStatus: String) {
        print("🔍 DEBUG: updateItemStatus called with status: \(newStatus)")
        guard !isUpdating else { 
            print("🔍 DEBUG: updateItemStatus blocked - already updating")
            return 
        }
        
        print("🔍 DEBUG: updateItemStatus proceeding with update")
        // Track user interaction to reset inactivity timer
        InactivityManager.trackUserInteraction()
        
        Task {
            await MainActor.run { 
                isUpdating = true
            }
            
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
                
                // Add a small delay to ensure the database update is reflected
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                // Refresh data after successful update
                await MainActor.run {
                    refreshData()
                }
            } catch {
                print("❌ Error updating item status: \(error)")
            }
            
            await MainActor.run {
                isUpdating = false
                print("🔍 DEBUG: isUpdating reset to false")
            }
        }
    }
    
    private func addItemNote(_ noteText: String, images: [UIImage]) {
        guard !isUpdating else { return }
        
        print("🔍 DEBUG: addItemNote called with text: '\(noteText)', images count: \(images.count)")
        
        // Track user interaction to reset inactivity timer
        InactivityManager.trackUserInteraction()
        
        Task {
            await MainActor.run { 
                isUpdating = true
            }
            
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
                    itemId: String(itemIndex),
                    user: appState.currentUserName,
                    text: noteText,
                    timestamp: Date()
                )
                
                updatedWorkOrder.items[itemIndex].notes.append(note)
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = appState.currentUserName
                
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
                
                // Add a small delay to ensure the database update is reflected
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                // Refresh data after successful update
                await MainActor.run {
                    refreshData()
                }
            } catch {
                print("❌ Error adding item note: \(error)")
            }
            
            await MainActor.run {
                isUpdating = false
                print("🔍 DEBUG: isUpdating reset to false")
            }
        }
    }
}

// MARK: - SimpleAddNotesView
