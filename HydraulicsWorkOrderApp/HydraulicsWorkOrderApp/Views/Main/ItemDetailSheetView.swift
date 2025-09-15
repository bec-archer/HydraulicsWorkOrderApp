import SwiftUI
import Foundation

// MARK: - ItemDetailSheetView
struct ItemDetailSheetView: View {
    let workOrder: WorkOrder
    let item: WO_Item
    let itemIndex: Int
    let onClose: () -> Void
    
    @EnvironmentObject var appState: AppState
    
    // Local state management - completely isolated from database updates
    @State private var currentItem: WO_Item
    @State private var completedReasons: [String] = []
    @State private var isUpdating = false
    @State private var hasAppeared = false
    @State private var lastButtonTapTime: Date = Date.distantPast
    
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
        self._currentItem = State(initialValue: item)
        self._completedReasons = State(initialValue: item.completedReasons)
    }
    
    // Use local state instead of database to prevent excessive re-rendering
    // Removed computed property to prevent excessive re-rendering
    
    
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
                Button(action: {
                    print("🔍 DEBUG: Status button tapped - setting showStatusSelection to true")
                    print("🔍 DEBUG: isUpdating when status button tapped: \(isUpdating)")
                    print("🔍 DEBUG: Status button action executing")
                    showStatusSelection = true
                    print("🔍 DEBUG: showStatusSelection is now: \(showStatusSelection)")
                }) {
                    StatusBadge(status: getActualItemStatus(currentItem))
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
                if !currentItem.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(currentItem.notes.reversed(), id: \.timestamp) { note in
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
        let _ = print("🔍 DEBUG: ItemDetailSheetView body being re-rendered")
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
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        print("🔍 DEBUG: 🎯 CLOSE BUTTON TAPPED")
                        onClose()
                    }
                    .onAppear {
                        print("🔍 DEBUG: Close button appeared")
                    }
                }
            })
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
            
        // Sync completedReasons state with currentItem
        if completedReasons != currentItem.completedReasons {
            print("🔍 DEBUG: Syncing completedReasons state with currentItem")
            completedReasons = currentItem.completedReasons
        }
        
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
                        // refreshData() removed - no longer needed
                    }
                }
            )
            .onDisappear {
                print("🔍 DEBUG: Add Notes sheet dismissed, refreshing data")
                // refreshData() removed - no longer needed
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
        let result = completedReasons.contains(reason)
        print("🔍 DEBUG: isReasonPerformed('\(reason)') = \(result), completedReasons: \(completedReasons)")
        return result
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
                // Use the shared database instance
                let workOrdersDB = WorkOrdersDatabase.shared
                
                // Update local state first on main actor
                await MainActor.run {
                    print("🔍 DEBUG: Before update - completedReasons: \(completedReasons)")
                    if completedReasons.contains(reason) {
                        completedReasons.removeAll { $0 == reason }
                        print("🔍 DEBUG: Removed reason: \(reason)")
                    } else {
                        completedReasons.append(reason)
                        print("🔍 DEBUG: Added reason: \(reason)")
                    }
                    print("🔍 DEBUG: After update - completedReasons: \(completedReasons)")
                    print("🔍 DEBUG: Local state updated for reason: \(reason)")
                }
                
                // Update the database using the existing method
                print("🔍 DEBUG: Starting database update for work order: \(workOrder.id)")
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    workOrdersDB.updateCompletedReasons(completedReasons, for: workOrder.id, itemIndex: itemIndex) { result in
                        switch result {
                        case .success:
                            print("🔍 DEBUG: Database update successful for work order: \(workOrder.id)")
                            continuation.resume()
                        case .failure(let error):
                            print("🔍 DEBUG: Database update failed for work order: \(workOrder.id), error: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                }
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
                // Use the shared database instance
                let workOrdersDB = WorkOrdersDatabase.shared
                
                // Update local state first
                var updatedItem = currentItem
                let status = WO_Status(
                    status: newStatus,
                    user: appState.currentUserName,
                    timestamp: Date()
                )
                updatedItem.statusHistory.append(status)
                currentItem = updatedItem
                print("🔍 DEBUG: Local state updated for status: \(newStatus)")
                
                // Update the database using the existing method
                let note = WO_Note(
                    workOrderId: workOrder.id,
                    itemId: String(itemIndex),
                    user: appState.currentUserName,
                    text: "Status changed to \(newStatus)",
                    timestamp: Date()
                )
                
                print("🔍 DEBUG: Starting database update for status change to: \(newStatus)")
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    workOrdersDB.updateItemStatusAndNote(newStatus, note: note, for: workOrder.id) { result in
                        switch result {
                        case .success:
                            print("🔍 DEBUG: Database update successful for status change to: \(newStatus)")
                            continuation.resume()
                        case .failure(let error):
                            print("🔍 DEBUG: Database update failed for status change to: \(newStatus), error: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                }
                print("🔍 DEBUG: Database update completed for status change to: \(newStatus)")
                
                // Add a small delay to ensure the database update is reflected
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                // Refresh data after successful update
                await MainActor.run {
                    // refreshData() removed - no longer needed
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
                // Use the shared database instance
                let workOrdersDB = WorkOrdersDatabase.shared
                
                // Update local state first
                var updatedItem = currentItem
                let note = WO_Note(
                    workOrderId: workOrder.id,
                    itemId: String(itemIndex),
                    user: appState.currentUserName,
                    text: noteText,
                    timestamp: Date()
                )
                updatedItem.notes.append(note)
                currentItem = updatedItem
                print("🔍 DEBUG: Local state updated for note: \(noteText)")
                
                // Update the database using the existing method
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    workOrdersDB.addItemNote(note, to: workOrder.id) { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                // Add a small delay to ensure the database update is reflected
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                // Refresh data after successful update
                await MainActor.run {
                    // refreshData() removed - no longer needed
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
