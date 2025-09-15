import SwiftUI
import Foundation

// MARK: - ItemDetailSheetView
struct ItemDetailSheetView: View {
    let workOrder: WorkOrder
    let item: WO_Item
    let itemIndex: Int
    let onClose: () -> Void
    
    @EnvironmentObject var appState: AppState
    
    // Simple state management - no local item state
    @State private var isUpdating = false
    @State private var hasAppeared = false
    @State private var lastButtonTapTime: Date = Date.distantPast
    
    // UI state
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL?
    @State private var showGallery = false
    @State private var showStatusSelection = false
    @State private var showAddNotes = false
    @State private var showCompletionDetailsSheet = false
    @State private var selectedItemForCompletion: WO_Item?
    @State private var selectedItemIndexForCompletion: Int?
    
    init(workOrder: WorkOrder, item: WO_Item, itemIndex: Int, onClose: @escaping () -> Void) {
        self.workOrder = workOrder
        self.item = item
        self.itemIndex = itemIndex
        self.onClose = onClose
    }
    
    // Always get fresh data from the database
    private var currentItem: WO_Item {
        let workOrdersDB = WorkOrdersDatabase.shared
        if let latestWorkOrder = workOrdersDB.workOrders.first(where: { $0.id == workOrder.id }),
           itemIndex < latestWorkOrder.items.count {
            let item = latestWorkOrder.items[itemIndex]
            print("🔍 DEBUG: currentItem computed - notes count: \(item.notes.count)")
            return item
        }
        print("🔍 DEBUG: currentItem computed - using fallback item, notes count: \(item.notes.count)")
        return item // Fallback to original item
    }
    
    private var completedReasons: [String] {
        return currentItem.completedReasons
    }
    
    
    // MARK: - View Components
    
    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: Composite WO_Number-ItemIndex (e.g., 250826-001-003)
            Text("\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeManager.shared.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // Middle: Reasons for Service (chosen at intake) — check to log "Service Performed — <Reason>"
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<currentItem.reasonsForService.count, id: \.self) { index in
                    let reason = currentItem.reasonsForService[index]
                    let _ = print("🔍 DEBUG: Rendering reason button \(index): '\(reason)' - isUpdating: \(isUpdating)")
                    HStack(spacing: 8) {
                        Button(action: {
                            print("🔍 DEBUG: 🎯 BUTTON ACTION CALLED for '\(reason)' (index: \(index))")
                            print("🔍 DEBUG: isUpdating when reason button tapped: \(isUpdating)")
                            print("🔍 DEBUG: Button action executing for reason: \(reason)")
                            toggleReasonCompletion(reason)
                        }) {
                            Image(systemName: isReasonPerformed(reason) ? "checkmark.square.fill" : "square")
                                .foregroundColor(isReasonPerformed(reason) ? .green : ThemeManager.shared.textSecondary)
                                .frame(width: 30, height: 30) // Larger touch target
                        }
                        .disabled(isUpdating)
                        .onAppear {
                            print("🔍 DEBUG: Button for '\(reason)' appeared - isUpdating: \(isUpdating)")
                            if index == 0 {
                                print("🔍 DEBUG: 🎯 FIRST BUTTON ('\(reason)') APPEARED")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
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
            VStack(spacing: 8) {
                let _ = print("🔍 DEBUG: Rendering status button section - isUpdating: \(isUpdating)")
                Button(action: {
                    print("🔍 DEBUG: Status button tapped - setting showStatusSelection to true")
                    print("🔍 DEBUG: isUpdating when status button tapped: \(isUpdating)")
                    print("🔍 DEBUG: Status button action executing")
                    showStatusSelection = true
                    print("🔍 DEBUG: showStatusSelection is now: \(showStatusSelection)")
                }) {
                    StatusBadge(status: getActualItemStatus(currentItem))
                }
                .onAppear {
                    print("🔍 DEBUG: Status button appeared - isUpdating: \(isUpdating)")
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isUpdating)
                .onTapGesture {
                    print("🔍 DEBUG: Status button onTapGesture triggered")
                    print("🔍 DEBUG: isUpdating when onTapGesture: \(isUpdating)")
                    if !isUpdating {
                        showStatusSelection = true
                        print("🔍 DEBUG: showStatusSelection set to true via onTapGesture")
                    }
                }
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            print("🔍 DEBUG: Status button simultaneous gesture triggered")
                            print("🔍 DEBUG: isUpdating when simultaneous gesture: \(isUpdating)")
                            if !isUpdating {
                                showStatusSelection = true
                                print("🔍 DEBUG: showStatusSelection set to true via simultaneous gesture")
                            }
                        }
                )
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
                    print("🔍 DEBUG: isUpdating when onTapGesture: \(isUpdating)")
                    if !isUpdating {
                        showAddNotes = true
                        print("🔍 DEBUG: showAddNotes set to true via onTapGesture")
                    }
                }
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            print("🔍 DEBUG: Add Notes button simultaneous gesture triggered")
                            print("🔍 DEBUG: isUpdating when simultaneous gesture: \(isUpdating)")
                            if !isUpdating {
                                showAddNotes = true
                                print("🔍 DEBUG: showAddNotes set to true via simultaneous gesture")
                            }
                        }
                )
            }
        }
    }
    
    private var itemDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    if let firstImageURL = currentItem.imageUrls.first {
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
                                .simultaneousGesture(
                                    TapGesture()
                                        .onEnded {
                                            print("🔍 DEBUG: Primary image simultaneous gesture triggered")
                                            print("🔍 DEBUG: Setting selectedImageURL to: \(firstImageURL)")
                                            selectedImageURL = URL(string: firstImageURL)
                                            print("🔍 DEBUG: selectedImageURL after setting: \(selectedImageURL?.absoluteString ?? "nil")")
                                            showImageViewer = true
                                            print("🔍 DEBUG: showImageViewer after setting: \(showImageViewer)")
                                        }
                                )
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
                    if currentItem.imageUrls.count > 1 {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(thumbSize), spacing: gridSpacing), count: 2), spacing: gridSpacing) {
                            ForEach(Array(currentItem.imageUrls.dropFirst().enumerated()), id: \.offset) { index, imageURL in
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
                                        .simultaneousGesture(
                                            TapGesture()
                                                .onEnded {
                                                    print("🔍 DEBUG: Thumbnail image simultaneous gesture triggered")
                                                    print("🔍 DEBUG: Setting selectedImageURL to: \(imageURL)")
                                                    selectedImageURL = URL(string: imageURL)
                                                    print("🔍 DEBUG: selectedImageURL after setting: \(selectedImageURL?.absoluteString ?? "nil")")
                                                    showImageViewer = true
                                                    print("🔍 DEBUG: showImageViewer after setting: \(showImageViewer)")
                                                }
                                        )
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
            
            // Right: Timeline (Notes & Status Changes)
            VStack(alignment: .leading, spacing: 12) {
                // ───── Timeline ─────
                let timelineItems = getCombinedTimeline()
                let _ = print("🔍 DEBUG: Timeline section - timelineItems.count: \(timelineItems.count)")
                if !timelineItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timeline")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(timelineItems, id: \.id) { timelineItem in
                            let _ = print("🔍 DEBUG: Rendering timeline item: \(timelineItem.type) by \(timelineItem.user)")
                            VStack(alignment: .leading, spacing: 4) {
                                // Timeline content
                                timelineItem.content
                                
                                // User and timestamp
                                HStack {
                                    Text("by \(timelineItem.user)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text(timelineItem.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else {
                    let _ = print("🔍 DEBUG: No timeline items to display")
                }
            }
        }
    }
    
    var body: some View {
        let _ = print("🔍 DEBUG: ItemDetailSheetView body being re-rendered")
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with close button
                HStack {
                    Button("Close") {
                        print("🔍 DEBUG: 🎯 CLOSE BUTTON TAPPED")
                        onClose()
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                    .frame(minWidth: 60, minHeight: 44) // Larger touch target
                    .background(Color.clear)
                    .onAppear {
                        print("🔍 DEBUG: Close button appeared")
                    }
                    .onTapGesture {
                        print("🔍 DEBUG: 🎯 CLOSE BUTTON ONTAPGESTURE")
                        onClose()
                    }
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                print("🔍 DEBUG: 🎯 CLOSE BUTTON SIMULTANEOUS GESTURE")
                                onClose()
                            }
                    )
                    
                    Spacer()
                    
                    Text("Item Details")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Invisible spacer to center the title
                    Text("Close")
                        .foregroundColor(.clear)
                        .font(.system(size: 16, weight: .medium))
                        .frame(minWidth: 60, minHeight: 44)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
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
            }
            .navigationBarHidden(true)
        }
        .trackUserInteraction() // Track user interactions to prevent inactivity logout
        .onAppear {
            print("🔍 DEBUG: ItemDetailSheetView onAppear")
            print("🔍 DEBUG: Currently viewing work order: \(workOrder.workOrderNumber)")
            print("🔍 DEBUG: Currently viewing item index: \(itemIndex)")
            print("🔍 DEBUG: Currently viewing item type: \(item.type)")
            print("🔍 DEBUG: Item reasons for service: \(item.reasonsForService)")
            print("🔍 DEBUG: Initial currentItem.completedReasons: \(currentItem.completedReasons)")
            print("🔍 DEBUG: Initial completedReasons state: \(completedReasons)")
            
        // No need to sync state - computed properties always return fresh data
        
        // TEMPORARILY DISABLED: State synchronization to test button responsiveness
        // CRITICAL: Sync with database state to prevent freezing
        // Check if the database has more recent data than our local state
        print("🔍 DEBUG: State synchronization temporarily disabled for testing")
        // print("🔍 DEBUG: Checking database sync - workOrders count: \(WorkOrdersDatabase.shared.workOrders.count)")
        // if let latestWorkOrder = WorkOrdersDatabase.shared.workOrders.first(where: { $0.id == workOrder.id }) {
        //     print("🔍 DEBUG: Found work order in database: \(latestWorkOrder.workOrderNumber)")
        //     if itemIndex < latestWorkOrder.items.count {
        //         let latestItem = latestWorkOrder.items[itemIndex]
        //         print("🔍 DEBUG: Database item completedReasons: \(latestItem.completedReasons)")
        //         print("🔍 DEBUG: Local item completedReasons: \(currentItem.completedReasons)")
        //         if latestItem.completedReasons != currentItem.completedReasons {
        //             print("🔍 DEBUG: Database has newer data - syncing local state")
        //             currentItem = latestItem
        //             completedReasons = latestItem.completedReasons
        //             print("🔍 DEBUG: State synchronized with database")
        //         } else {
        //             print("🔍 DEBUG: Database and local state are in sync")
        //         }
        //     } else {
        //         print("🔍 DEBUG: Item index \(itemIndex) out of bounds for work order")
        //     }
        // } else {
        //     print("🔍 DEBUG: Work order \(workOrder.workOrderNumber) not found in database")
        // }
            
            // Only reset critical state that could cause freezing
            isUpdating = false
            lastButtonTapTime = Date.distantPast
            
            print("🔍 DEBUG: Critical state reset on appear")
        }
        .onDisappear {
            print("🔍 DEBUG: ItemDetailSheetView onDisappear")
            print("🔍 DEBUG: Closing work order: \(workOrder.workOrderNumber)")
            print("🔍 DEBUG: Closing item index: \(itemIndex)")
            
            // Reset all state to prevent accumulation across sheet instances
            isUpdating = false
            hasAppeared = false
            lastButtonTapTime = Date.distantPast
            showImageViewer = false
            selectedImageURL = nil
            showGallery = false
            showStatusSelection = false
            showAddNotes = false
            showCompletionDetailsSheet = false
            selectedItemForCompletion = nil
            selectedItemIndexForCompletion = nil
            
            print("🔍 DEBUG: All state reset on disappear")
        }
        .fullScreenCover(isPresented: $showGallery) {
            ImageGalleryView(images: currentItem.imageUrls, title: "\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
        }
        .fullScreenCover(isPresented: $showStatusSelection) {
            StatusSelectionView(
                currentStatus: getActualItemStatus(currentItem),
                onStatusSelected: { newStatus in
                    print("🔍 DEBUG: ItemDetailSheetView - Status selected: \(newStatus)")
                    
                    // Check if status is "Complete" - show completion details sheet first
                    if newStatus.lowercased() == "complete" {
                        print("🔍 DEBUG: Complete status requested - showing completion details sheet")
                        selectedItemForCompletion = currentItem
                        selectedItemIndexForCompletion = itemIndex
                        showCompletionDetailsSheet = true
                        // Note: Status will only change to Complete AFTER completion details are saved
                    } else {
                        // For other statuses, update directly
                        updateItemStatus(newStatus)
                    }
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
                        // refreshData() removed - no longer needed
                    }
                }
            )
            .onDisappear {
                print("🔍 DEBUG: Add Notes sheet dismissed, refreshing data")
                // refreshData() removed - no longer needed
            }
        }
        .sheet(isPresented: $showCompletionDetailsSheet) {
            if let item = selectedItemForCompletion, let itemIndex = selectedItemIndexForCompletion {
                CompletionDetailsSheet(
                    workOrder: workOrder,
                    item: item,
                    itemIndex: itemIndex,
                    onCompletionDetailsSaved: { partsUsed, hoursWorked, cost in
                        Task {
                            // Only change status to Complete after completion details are saved
                            await updateItemStatusWithCompletion(
                                "Complete",
                                partsUsed: partsUsed,
                                hoursWorked: hoursWorked,
                                cost: cost
                            )
                        }
                    },
                    onCompletionCancelled: {
                        // If user cancels, don't change the status - it remains as it was
                        print("🔍 DEBUG: Completion details sheet cancelled - status unchanged")
                    }
                )
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
                    print("🔍 DEBUG: showImageViewer state: \(showImageViewer)")
                }
            }
        }
        .onChange(of: showImageViewer) { newValue in
            if newValue {
                print("🔍 DEBUG: fullScreenCover triggered - showImageViewer: \(newValue)")
                print("🔍 DEBUG: fullScreenCover triggered - selectedImageURL: \(selectedImageURL?.absoluteString ?? "nil")")
            }
        }
    }
    
    // MARK: - Helper Functions
    func isReasonPerformed(_ reason: String) -> Bool {
        let result = completedReasons.contains(reason)
        print("🔍 DEBUG: isReasonPerformed('\(reason)') = \(result), completedReasons: \(completedReasons)")
        return result
    }
    
    func getActualItemStatus(_ item: WO_Item) -> String {
        let status = item.statusHistory.last?.status ?? "Checked In"
        print("🔍 DEBUG: getActualItemStatus called - statusHistory count: \(item.statusHistory.count), last status: \(status)")
        if item.statusHistory.count > 0 {
            print("🔍 DEBUG: Last 3 statuses: \(item.statusHistory.suffix(3).map { $0.status })")
        }
        return status
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
        
        // Debounce rapid button taps to prevent multiple simultaneous updates
        let now = Date()
        if now.timeIntervalSince(lastButtonTapTime) < 0.5 { // 500ms debounce
            print("🔍 DEBUG: Button tap debounced - too soon since last tap")
            return
        }
        lastButtonTapTime = now
        
        // Track user interaction to reset inactivity timer
        InactivityManager.trackUserInteraction()
        
        Task {
            await MainActor.run { 
                isUpdating = true
            }
            
            do {
                // Get fresh data from database
                let workOrdersDB = WorkOrdersDatabase.shared
                var updatedWorkOrder = workOrder
                var updatedItem = currentItem
                
                // Toggle the reason
                if updatedItem.completedReasons.contains(reason) {
                    updatedItem.completedReasons.removeAll { $0 == reason }
                    print("🔍 DEBUG: Removed reason: \(reason)")
                } else {
                    updatedItem.completedReasons.append(reason)
                    print("🔍 DEBUG: Added reason: \(reason)")
                }
                
                updatedItem.lastModified = Date()
                updatedItem.lastModifiedBy = appState.currentUserName
                
                // Update work order
                updatedWorkOrder.items[itemIndex] = updatedItem
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = appState.currentUserName
                
                print("🔍 DEBUG: Starting database update for work order: \(workOrder.id)")
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
                print("🔍 DEBUG: Database update completed for work order: \(workOrder.id)")
                
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
                // Get fresh data from database
                let workOrdersDB = WorkOrdersDatabase.shared
                var updatedWorkOrder = workOrder
                var updatedItem = currentItem
                
                // Add new status
                let status = WO_Status(
                    status: newStatus,
                    user: appState.currentUserName,
                    timestamp: Date()
                )
                updatedItem.statusHistory.append(status)
                updatedItem.lastModified = Date()
                updatedItem.lastModifiedBy = appState.currentUserName
                
                // Update work order
                updatedWorkOrder.items[itemIndex] = updatedItem
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = appState.currentUserName
                
                print("🔍 DEBUG: Starting database update for status change to: \(newStatus)")
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
                print("🔍 DEBUG: Database update completed for status change to: \(newStatus)")
                
            } catch {
                print("❌ Error updating item status: \(error)")
            }
            
            await MainActor.run {
                isUpdating = false
                print("🔍 DEBUG: isUpdating reset to false")
            }
        }
    }
    
    private func updateItemStatusWithCompletion(_ newStatus: String, partsUsed: String, hoursWorked: String, cost: String) async {
        print("🔍 DEBUG: updateItemStatusWithCompletion called with status: \(newStatus)")
        print("🔍 DEBUG: Parts: '\(partsUsed)', Hours: '\(hoursWorked)', Cost: '\(cost)'")
        
        await MainActor.run { 
            isUpdating = true
        }
        
        do {
            // Get fresh data from database
            let workOrdersDB = WorkOrdersDatabase.shared
            var updatedWorkOrder = workOrder
            var updatedItem = currentItem
            
            // Add new status and completion details
            let status = WO_Status(
                status: newStatus,
                user: appState.currentUserName,
                timestamp: Date()
            )
            updatedItem.statusHistory.append(status)
            updatedItem.partsUsed = partsUsed
            updatedItem.hoursWorked = hoursWorked
            updatedItem.finalCost = cost
            updatedItem.lastModified = Date()
            updatedItem.lastModifiedBy = appState.currentUserName
            
            // Update work order
            updatedWorkOrder.items[itemIndex] = updatedItem
            updatedWorkOrder.lastModified = Date()
            updatedWorkOrder.lastModifiedBy = appState.currentUserName
            
            print("🔍 DEBUG: Starting database update for status change to: \(newStatus) with completion details")
            try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
            print("🔍 DEBUG: Database update completed for status change to: \(newStatus) with completion details")
            
        } catch {
            print("❌ Error updating item status with completion details: \(error)")
        }
        
        await MainActor.run {
            isUpdating = false
            print("🔍 DEBUG: isUpdating reset to false")
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
                // Get fresh data from database
                let workOrdersDB = WorkOrdersDatabase.shared
                var updatedWorkOrder = workOrder
                var updatedItem = currentItem
                
                // Upload images if any
                var imageUrls: [String] = []
                var thumbnailUrls: [String] = []
                if !images.isEmpty {
                    print("🔍 DEBUG: Uploading \(images.count) images for note")
                    let imageService = ImageManagementService.shared
                    let result = try await imageService.uploadImages(images, for: workOrder.id, itemId: currentItem.id)
                    imageUrls = result.imageURLs
                    thumbnailUrls = result.thumbnailURLs
                    print("🔍 DEBUG: Successfully uploaded \(imageUrls.count) images and \(thumbnailUrls.count) thumbnails")
                    for (index, url) in imageUrls.enumerated() {
                        print("🔍 DEBUG: Image \(index + 1) URL: \(url)")
                    }
                    for (index, url) in thumbnailUrls.enumerated() {
                        print("🔍 DEBUG: Thumbnail \(index + 1) URL: \(url)")
                    }
                }
                
                // Create the note with thumbnail URLs (for display in notes list)
                let note = WO_Note(
                    workOrderId: workOrder.id,
                    itemId: String(itemIndex),
                    user: appState.currentUserName,
                    text: noteText,
                    timestamp: Date(),
                    imageUrls: thumbnailUrls // Use thumbnails for note display
                )
                updatedItem.notes.append(note)
                
                // Add full-size images to item's image arrays (for main gallery)
                for imageUrl in imageUrls {
                    updatedItem.imageUrls.append(imageUrl)
                }
                
                // Add thumbnail URLs to item's thumbnail array (for main gallery thumbnails)
                for thumbnailUrl in thumbnailUrls {
                    updatedItem.thumbUrls.append(thumbnailUrl)
                }
                
                updatedItem.lastModified = Date()
                updatedItem.lastModifiedBy = appState.currentUserName
                
                print("🔍 DEBUG: Note added to item: \(noteText)")
                print("🔍 DEBUG: Note has \(thumbnailUrls.count) thumbnail images")
                print("🔍 DEBUG: Item now has \(updatedItem.imageUrls.count) full images and \(updatedItem.thumbUrls.count) thumbnails")
                print("🔍 DEBUG: Updated item now has \(updatedItem.notes.count) notes")
                
                // Update work order
                updatedWorkOrder.items[itemIndex] = updatedItem
                updatedWorkOrder.lastModified = Date()
                updatedWorkOrder.lastModifiedBy = appState.currentUserName
                
                print("🔍 DEBUG: Starting database update for work order: \(workOrder.id)")
                try await workOrdersDB.updateWorkOrder(updatedWorkOrder)
                print("🔍 DEBUG: Database update completed for work order: \(workOrder.id)")
                
            } catch {
                print("❌ Error adding item note: \(error)")
            }
            
            await MainActor.run {
                isUpdating = false
                print("🔍 DEBUG: isUpdating reset to false")
            }
        }
    }
    
    // MARK: - Timeline Helper Functions
    
    /// Timeline item structure for combining notes and status changes
    struct TimelineItem: Identifiable {
        let id: UUID
        let timestamp: Date
        let user: String
        let content: AnyView
        let type: TimelineItemType
        
        enum TimelineItemType {
            case note
            case status
            case initialStatus
        }
    }
    
    /// Get combined timeline of notes and status changes, sorted chronologically
    func getCombinedTimeline() -> [TimelineItem] {
        var timelineItems: [TimelineItem] = []
        
        // Add initial "Checked In" status if no status history exists
        if currentItem.statusHistory.isEmpty {
            timelineItems.append(TimelineItem(
                id: UUID(),
                timestamp: currentItem.lastModified,
                user: "System",
                content: AnyView(
                    Text("Checked In")
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                ),
                type: .initialStatus
            ))
        }
        
        // Add status history items (excluding "Service Performed" entries)
        for status in currentItem.statusHistory {
            // Skip "Service Performed" entries since they're already tracked in notes
            if !status.status.hasPrefix("Service Performed") {
                timelineItems.append(TimelineItem(
                    id: status.id,
                    timestamp: status.timestamp,
                    user: status.user,
                    content: AnyView(
                        Text(status.status)
                            .font(.system(size: 12 * 1.2))
                            .fontWeight(.bold)
                            .foregroundColor(getStatusColor(status.status))
                    ),
                    type: .status
                ))
            }
        }
        
        // Add note items
        for note in currentItem.notes {
            timelineItems.append(TimelineItem(
                id: note.id,
                timestamp: note.timestamp,
                user: note.user,
                content: AnyView(
                    VStack(alignment: .leading, spacing: 4) {
                        // Show text if available
                        if !note.text.isEmpty {
                            reasonServiceNoteText(note.text)
                        }
                        
                        // Show image thumbnails if available
                        if !note.imageUrls.isEmpty {
                            let _ = print("🔍 DEBUG: Note has \(note.imageUrls.count) image URLs: \(note.imageUrls)")
                            HStack(spacing: 4) {
                                ForEach(note.imageUrls.prefix(3), id: \.self) { imageUrl in
                                    Button(action: {
                                        selectedImageURL = URL(string: imageUrl)
                                        showImageViewer = true
                                    }) {
                                        AsyncImage(url: URL(string: imageUrl)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 48, height: 48)
                                                .clipped()
                                                .cornerRadius(6)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(ThemeManager.shared.border.opacity(0.3))
                                                .frame(width: 48, height: 48)
                                                .cornerRadius(6)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                // Show "+X more" if there are more than 3 images
                                if note.imageUrls.count > 3 {
                                    Text("+\(note.imageUrls.count - 3)")
                                        .font(.system(size: 10 * 1.2))
                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                        .frame(width: 48, height: 48)
                                        .background(ThemeManager.shared.border.opacity(0.3))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        
                        // Show "Image only" text if there's no text but there are images
                        if note.text.isEmpty && !note.imageUrls.isEmpty {
                            Text("Image only")
                                .font(.system(size: 10 * 1.2))
                                .foregroundColor(ThemeManager.shared.textSecondary)
                                .italic()
                        }
                    }
                ),
                type: .note
            ))
        }
        
        // Sort all items by timestamp (oldest first)
        return timelineItems.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Get color for status display
    func getStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "checked in":
            return Color.blue
        case "disassembly":
            return Color.purple
        case "in progress":
            return Color.yellow
        case "test failed":
            return Color.red
        case "complete", "completed":
            return Color.green
        case "closed":
            return Color.gray
        default:
            return ThemeManager.shared.textPrimary
        }
    }
    
    /// Format reason service note text with emoji handling
    @ViewBuilder
    func reasonServiceNoteText(_ text: String) -> some View {
        if text.hasPrefix("✅") || text.hasPrefix("❌") {
            let components = text.components(separatedBy: " • ")
            if components.count == 2 {
                let emoji = components[0]
                let reasonText = components[1]
                
                HStack(spacing: 4) {
                    Text(emoji)
                        .font(.system(size: 12 * 1.2))
                    Text(reasonText)
                        .font(.system(size: 12 * 1.2, weight: .bold))
                        .foregroundColor(ThemeManager.shared.textPrimary)
                }
            } else {
                Text(text)
                    .font(.system(size: 12 * 1.2))
                    .foregroundColor(ThemeManager.shared.textPrimary)
            }
        } else {
            Text(text)
                .font(.system(size: 12 * 1.2))
                .foregroundColor(ThemeManager.shared.textPrimary)
        }
    }
}

// MARK: - SimpleAddNotesView
