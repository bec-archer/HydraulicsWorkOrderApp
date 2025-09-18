//
//  FilteredWorkOrderDetailView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Assistant on 1/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 FilteredWorkOrderDetailView.swift
// Work order detail view that matches WorkOrderDetailView structure exactly,
// but shows the scanned item first with a visual indicator
// ─────────────────────────────────────────────────────────────

import SwiftUI
import Foundation
import FirebaseStorage
import FirebaseFirestore
import UIKit
import Combine

// MARK: - FilteredWorkOrderDetailView
struct FilteredWorkOrderDetailView: View {
    // MARK: - Properties
    let workOrder: WorkOrder
    let scannedItem: WO_Item
    let scannedItemIndex: Int
    
    // MARK: - Environment
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @StateObject private var viewModel: WorkOrderDetailViewModel
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL?
    @State private var showStatusSelection = false
    @State private var showAddNotes = false
    @State private var showGallery = false
    @State private var showDeleteConfirm = false
    @State private var showTagReplacement = false
    @State private var selectedItemForTagReplacement: WO_Item?
    @State private var showCompletionDetailsSheet = false
    @State private var selectedItemForCompletion: WO_Item?
    @State private var selectedItemIndexForCompletion: Int?
    @State private var showingPhoneActions = false
    
    // MARK: - Computed Properties
    private var reorderedItems: [(item: WO_Item, originalIndex: Int, isScanned: Bool)] {
        var items: [(item: WO_Item, originalIndex: Int, isScanned: Bool)] = []
        
        // Add scanned item first
        items.append((item: scannedItem, originalIndex: scannedItemIndex, isScanned: true))
        
        // Add other items
        for (index, item) in workOrder.items.enumerated() {
            if index != scannedItemIndex {
                items.append((item: item, originalIndex: index, isScanned: false))
            }
        }
        
        return items
    }
    
    private var canDelete: Bool {
        appState.isManager || appState.isAdmin || appState.isSuperAdmin
    }
    
    // MARK: - Initializer
    init(workOrder: WorkOrder, scannedItem: WO_Item, scannedItemIndex: Int) {
        self.workOrder = workOrder
        self.scannedItem = scannedItem
        self.scannedItemIndex = scannedItemIndex
        self._viewModel = StateObject(wrappedValue: WorkOrderDetailViewModel(workOrder: workOrder))
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Main content
            ScrollView {
                VStack(spacing: 20) {
                    // Version Mismatch Banner
                    VersionMismatchBanner(items: viewModel.workOrder.items)
                        .padding(.horizontal)
                    
                    // Work Order Header Banner (same as WorkOrderDetailView)
                    workOrderHeaderBanner
                    
                    // Items Section (with scanned item first)
                    itemsSection
                }
                .padding()
            }
            
            // Loading overlay
            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView("Loading...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
        }
        .navigationTitle("Work Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if canDelete {
                        Button("Delete Work Order", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                    
                    Button("Toggle Flag") {
                        Task {
                            await viewModel.toggleFlagged()
                        }
                    }
                    
                    Button("Mark Completed") {
                        Task {
                            await viewModel.markCompleted()
                        }
                    }
                    
                    Button("Mark Closed") {
                        Task {
                            await viewModel.markClosed()
                        }
                    }
                    
                    // Tag replacement (Manager/Admin only)
                    if appState.isManager || appState.isAdmin || appState.isSuperAdmin {
                        Button("Replace Tag") {
                            // For now, use the first item with a tag
                            if let itemWithTag = viewModel.workOrder.items.first(where: { $0.assetTagId != nil }) {
                                selectedItemForTagReplacement = itemWithTag
                                showTagReplacement = true
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Work Order", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteWorkOrder()
                    appState.navigateToView(.activeWorkOrders)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this work order? This action cannot be undone.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $viewModel.showAddNoteSheet) {
            AddNoteSheet(
                workOrder: viewModel.workOrder,
                onAddNote: { note in
                    Task {
                        await viewModel.addItemNote(note, to: viewModel.selectedItemIndex ?? 0)
                    }
                }
            )
        }
        .sheet(isPresented: $showTagReplacement) {
            if let item = selectedItemForTagReplacement {
                TagReplacementView(
                    workOrderItem: item,
                    onTagReplaced: { replacement in
                        Task {
                            await viewModel.replaceTag(replacement, for: item)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showCompletionDetailsSheet) {
            if let item = selectedItemForCompletion,
               let itemIndex = selectedItemIndexForCompletion {
                CompletionDetailsSheet(
                    workOrder: viewModel.workOrder,
                    item: item,
                    itemIndex: itemIndex,
                    onCompletionDetailsSaved: { partsUsed, hoursWorked, cost in
                        Task {
                            // Only change status to Complete after completion details are saved
                            await viewModel.updateItemStatusWithCompletion(
                                "Complete",
                                for: itemIndex,
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
            }
        }
        .confirmationDialog("Phone Actions", isPresented: $showingPhoneActions) {
            Button("Call") {
                if let url = URL(string: "tel:\(viewModel.customerPhone)") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Text") {
                if let url = URL(string: "sms:\(viewModel.customerPhone)") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Copy") {
                UIPasteboard.general.string = viewModel.customerPhone
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Work Order Header Banner (same as WorkOrderDetailView)
    private var workOrderHeaderBanner: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left side: Work Order number and timestamp
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.workOrder.workOrderNumber)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeManager.shared.textPrimary)
                
                Text(viewModel.workOrder.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.caption)
                    .foregroundColor(ThemeManager.shared.textSecondary)
            }
            
            Spacer()
            
            // Right side: Customer name (with optional emoji), Flag toggle, and phone link
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    if let emoji = viewModel.workOrder.customerEmojiTag, !emoji.isEmpty {
                        Text(emoji)
                            .font(ThemeManager.shared.labelFont)
                    }
                    Text(viewModel.workOrder.customerName)
                        .font(ThemeManager.shared.labelFont)
                        .foregroundColor(ThemeManager.shared.textPrimary)

                    // Small flag toggle to match header affordance
                    Button(action: {
                        Task { await viewModel.toggleFlagged() }
                    }) {
                        Image(systemName: viewModel.workOrder.flagged ? "flag.fill" : "flag")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ThemeManager.shared.linkColor)
                    .accessibilityLabel(viewModel.workOrder.flagged ? "Unflag work order" : "Flag work order")
                }

                Button(action: { showingPhoneActions = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                        Text(viewModel.workOrder.customerPhone.formattedPhoneNumber)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(ThemeManager.shared.linkColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ThemeManager.shared.cardBackground)
        .cornerRadius(ThemeManager.shared.cardCornerRadius)
        .shadow(
            color: ThemeManager.shared.cardShadowColor.opacity(ThemeManager.shared.cardShadowOpacity),
            radius: 8,
            x: 0,
            y: 4
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Work Order \(viewModel.workOrder.workOrderNumber), created \(viewModel.workOrder.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute()), customer \(viewModel.workOrder.customerName), phone \(viewModel.workOrder.customerPhone.formattedPhoneNumber)\(viewModel.workOrder.flagged ? ", flagged" : "")"
        )
    }
    
    // MARK: - Items Section (with scanned item first)
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Work Order Items")
                    .font(.headline)
                    .foregroundColor(ThemeManager.shared.textPrimary)
                Spacer()
                Text("\(viewModel.workOrder.items.count) items")
                    .font(.subheadline)
                    .foregroundColor(ThemeManager.shared.textSecondary)
            }
            
            LazyVStack(spacing: 14) {
                ForEach(Array(reorderedItems.enumerated()), id: \.element.item.id) { displayIndex, itemData in
                    WOItemCard(
                        workOrder: viewModel.workOrder,
                        item: itemData.item,
                        itemIndex: itemData.originalIndex,
                        isScanned: itemData.isScanned,
                        onImageTap: { imageURL in
                            if let url = URL(string: imageURL) {
                                selectedImageURL = url
                                showImageViewer = true
                            }
                        },
                        onReasonToggled: { reason in
                            print("🔍 DEBUG: Checkbox toggled for reason: '\(reason)' on item index: \(itemData.originalIndex)")
                            Task { @MainActor in
                                print("🔍 DEBUG: About to call toggleServicePerformedStatus")
                                await viewModel.toggleServicePerformedStatus(for: itemData.originalIndex, reason: reason)
                                print("🔍 DEBUG: toggleServicePerformedStatus completed")
                            }
                        },
                        onStatusChanged: { newStatus in
                            print("🔍 DEBUG: Status change requested to: '\(newStatus)' for item index: \(itemData.originalIndex)")
                            
                            // Check if status is "Complete" - show completion details sheet first
                            if newStatus.lowercased() == "complete" {
                                print("🔍 DEBUG: Complete status requested - showing completion details sheet")
                                selectedItemForCompletion = itemData.item
                                selectedItemIndexForCompletion = itemData.originalIndex
                                showCompletionDetailsSheet = true
                                // Note: Status will only change to Complete AFTER completion details are saved
                            } else {
                                // For other statuses, update directly
                                Task { @MainActor in
                                    print("🔍 DEBUG: About to call updateItemStatus for non-complete status")
                                    await viewModel.updateItemStatus(newStatus, for: itemData.originalIndex)
                                    print("🔍 DEBUG: updateItemStatus completed")
                                }
                            }
                        },
                        onNotesAdded: { noteText, images in
                            print("🔍 DEBUG: Notes added: '\(noteText)' with \(images.count) images for item index: \(itemData.originalIndex)")
                            Task { @MainActor in
                                await viewModel.addItemNoteWithImages(noteText, images: images, to: itemData.originalIndex)
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - WOItemCard Component (modified from WorkOrderDetailView)
    private struct WOItemCard: View {
        let workOrder: WorkOrder
        let item: WO_Item
        let itemIndex: Int
        let isScanned: Bool
        let onImageTap: (String) -> Void
        let onReasonToggled: (String) -> Void
        let onStatusChanged: (String) -> Void
        let onNotesAdded: (String, [UIImage]) -> Void
        
        @State private var showImageViewer = false
        @State private var selectedImageURL: URL?
        @State private var showGallery = false
        @State private var showStatusSelection = false
        @State private var showAddNotes = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header row: Scanned indicator + Composite item number • Reasons (checkboxes) • StatusBadge
                HStack(alignment: .top, spacing: 12) {
                    // Left: Scanned indicator (if this is the scanned item)
                    if isScanned {
                        HStack(spacing: 4) {
                            Image(systemName: "qrcode.viewfinder")
                                .foregroundColor(Color(hex: "#FFC500"))
                                .font(.caption)
                            Text("SCANNED")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#FFC500"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#FFC500").opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    // Composite WO_Number-ItemIndex (e.g., 250826-001-003)
                    Text("\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
                        .font(.headline)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    
                    Spacer(minLength: 8)
                    
                    // Middle: Reasons for Service (chosen at intake) — check to log "Service Performed — <Reason>"
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(item.reasonsForService, id: \.self) { reason in
                            HStack(spacing: 8) {
                                Button(action: {
                                    onReasonToggled(reason)
                                }) {
                                    Image(systemName: isReasonPerformed(reason) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(isReasonPerformed(reason) ? .green : ThemeManager.shared.textSecondary)
                                }
                                
                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundColor(ThemeManager.shared.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            
                            // Show reason notes if "Other" has notes
                            if reason.lowercased().contains("other") && !(item.reasonNotes?.isEmpty ?? true) {
                                Text(item.reasonNotes ?? "")
                                    .font(.caption)
                                    .foregroundColor(ThemeManager.shared.textSecondary)
                                    .padding(.leading, 24)
                            }
                        }
                    }
                    
                    // Right: StatusBadge (tappable) and Add Notes button
                    HStack(spacing: 8) {
                        Button(action: {
                            showStatusSelection = true
                        }) {
                            StatusBadge(status: getActualItemStatus(item))
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
                Text(item.type.isEmpty ? "Item" : item.type)
                    .font(.subheadline)
                    .foregroundColor(ThemeManager.shared.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Size / Color / Machine / Brand / Wait summary (muted), with inline "Other" note if present
                if !summaryLineForItem(item).isEmpty {
                    Text(summaryLineForItem(item))
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

                        // Primary image (large, 1:1)
                        if let firstImageURL = item.imageUrls.first {
                            AsyncImage(url: URL(string: firstImageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: primarySize, height: primarySize)
                                    .clipped()
                                    .cornerRadius(ThemeManager.shared.cardCornerRadius)
                                    .onTapGesture {
                                        onImageTap(firstImageURL)
                                    }
                            } placeholder: {
                                Rectangle()
                                    .fill(ThemeManager.shared.border.opacity(0.3))
                                    .frame(width: primarySize, height: primarySize)
                                    .cornerRadius(ThemeManager.shared.cardCornerRadius)
                                    .overlay(ProgressView())
                            }
                        } else {
                            Rectangle()
                                .fill(ThemeManager.shared.border.opacity(0.3))
                                .frame(width: primarySize, height: primarySize)
                                .cornerRadius(ThemeManager.shared.cardCornerRadius)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                            .font(.title)
                                            .foregroundColor(ThemeManager.shared.textSecondary)
                                        Text("No Image")
                                            .font(.caption)
                                            .foregroundColor(ThemeManager.shared.textSecondary)
                                    }
                                )
                        }
                        
                        // Thumbnail grid for additional images (2×2 max)
                        if item.imageUrls.count > 1 {
                            let thumbnails = Array(item.imageUrls.dropFirst().prefix(4))
                            LazyVGrid(columns: [
                                GridItem(.fixed(thumbSize), spacing: gridSpacing),
                                GridItem(.fixed(thumbSize), spacing: gridSpacing)
                            ], spacing: gridSpacing) {
                                ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, imageURL in
                                    AsyncImage(url: URL(string: imageURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: thumbSize, height: thumbSize)
                                            .clipped()
                                            .cornerRadius(8)
                                            .onTapGesture {
                                                onImageTap(imageURL)
                                            }
                                    } placeholder: {
                                        Rectangle()
                                            .fill(ThemeManager.shared.border.opacity(0.3))
                                            .frame(width: thumbSize, height: thumbSize)
                                            .cornerRadius(8)
                                    }
                                }
                                
                                // Show "+X more" if there are more than 5 total images
                                if item.imageUrls.count > 5 {
                                    Button(action: {
                                        showGallery = true
                                    }) {
                                        ZStack {
                                            Rectangle()
                                                .fill(ThemeManager.shared.border.opacity(0.3))
                                                .frame(width: thumbSize, height: thumbSize)
                                                .cornerRadius(8)
                                            
                                            Text("+\(item.imageUrls.count - 5)")
                                                .font(.headline)
                                                .foregroundColor(ThemeManager.shared.textPrimary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    
                    // Right: Notes & Status Timeline
                    VStack(alignment: .leading, spacing: 12) {
                        // Notes & Status Timeline
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Timeline")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(ThemeManager.shared.textPrimary)
                            
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(getCombinedTimeline(), id: \.id) { timelineItem in
                                        HStack(alignment: .top, spacing: 8) {
                                            // Timeline dot
                                            Circle()
                                                .fill(getTimelineDotColor(for: timelineItem.type))
                                                .frame(width: 8, height: 8)
                                                .padding(.top, 4)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                timelineItem.content
                                                
                                                HStack {
                                                    Text(timelineItem.user)
                                                        .font(.caption2)
                                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                                    Text("•")
                                                        .font(.caption2)
                                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                                    Text(timelineItem.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                                                        .font(.caption2)
                                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(ThemeManager.shared.cardBackground)
            .cornerRadius(ThemeManager.shared.cardCornerRadius)
            .shadow(
                color: ThemeManager.shared.cardShadowColor.opacity(ThemeManager.shared.cardShadowOpacity),
                radius: 8,
                x: 0,
                y: 4
            )
            .overlay(
                // Add yellow border for scanned item
                isScanned ? RoundedRectangle(cornerRadius: ThemeManager.shared.cardCornerRadius)
                    .stroke(Color(hex: "#FFC500"), lineWidth: 2) : nil
            )
            .sheet(isPresented: $showStatusSelection) {
                StatusSelectionView(
                    currentStatus: getActualItemStatus(item),
                    onStatusSelected: { newStatus in
                        onStatusChanged(newStatus)
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
                        onNotesAdded(noteText, images)
                        showAddNotes = false
                    }
                )
            }
            .sheet(isPresented: $showGallery) {
                ImageGalleryView(images: item.imageUrls, title: "\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
            }
        }
        
        // MARK: - Helper Methods
        private func isReasonPerformed(_ reason: String) -> Bool {
            let expectedStatus = "Service Performed — \(reason)"
            return item.statusHistory.contains { status in
                status.status == expectedStatus
            }
        }
        
        private func getActualItemStatus(_ item: WO_Item) -> String {
            return item.statusHistory.last?.status ?? "Checked In"
        }
        
        private func summaryLineForItem(_ item: WO_Item) -> String {
            // Builds: Size / Color / Machine / Brand / Wait (skip empties)
            let size = item.dropdowns["size"]
            let color = item.dropdowns["color"]
            let machineType = item.dropdowns["machineType"]
            let brand = item.dropdowns["machineBrand"]
            let wait = item.dropdowns["waitTime"]
            
            let parts = [size, color, machineType, brand, wait].compactMap { v -> String? in
                guard let s = v?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
                return s
            }
            return parts.joined(separator: " • ")
        }
        
        // MARK: - Timeline Item Structure
        enum TimelineItemType {
            case status
            case note
            case initialStatus
        }
        
        struct TimelineItem: Identifiable {
            let id: UUID
            let timestamp: Date
            let user: String
            let content: AnyView
            let type: TimelineItemType
        }
        
        private func getTimelineDotColor(for type: TimelineItemType) -> Color {
            switch type {
            case .status:
                return Color.blue
            case .note:
                return Color.green
            case .initialStatus:
                return Color.gray
            }
        }
        
        // MARK: - Timeline Helper
        func getCombinedTimeline() -> [TimelineItem] {
            var timelineItems: [TimelineItem] = []
            
            // Add initial "Checked In" status if no status history exists
            if item.statusHistory.isEmpty {
                timelineItems.append(TimelineItem(
                    id: UUID(),
                    timestamp: item.lastModified,
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
            for status in item.statusHistory {
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
            for note in item.notes {
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
                                HStack(spacing: 4) {
                                    ForEach(note.imageUrls.prefix(3), id: \.self) { imageUrl in
                                        Button(action: {
                                            onImageTap(imageUrl)
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
        
        private func getStatusColor(_ status: String) -> Color {
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
        
        @ViewBuilder
        private func reasonServiceNoteText(_ text: String) -> some View {
            // Check if this is a Reasons for Service note (starts with ✅ or ❌)
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
}

// MARK: - Preview
#Preview {
    let sampleWorkOrder = WorkOrder(
        id: "preview-wo",
        createdBy: "Tech",
        customerId: "preview-customer",
        customerName: "John Doe",
        customerCompany: "ABC Company",
        customerEmail: "john@abc.com",
        customerTaxExempt: false,
        customerPhone: "(555) 123-4567",
        workOrderType: "Intake",
        primaryImageURL: nil,
        timestamp: Date(),
        status: "Checked In",
        workOrderNumber: "250826-001",
        flagged: false,
        assetTagId: nil,
        estimatedCost: nil,
        finalCost: nil,
        dropdowns: [:],
        dropdownSchemaVersion: 1,
        lastModified: Date(),
        lastModifiedBy: "Tech",
        tagBypassReason: nil,
        isDeleted: false,
        syncStatus: "pending",
        lastSyncDate: nil,
        notes: [],
        items: [
            WO_Item(
                id: UUID(),
                itemNumber: "250826-001-001",
                assetTagId: "TAG-12345",
                type: "Hydraulic Pump",
                imageUrls: ["https://picsum.photos/400/300"],
                thumbUrls: ["https://picsum.photos/100/100"],
                localImages: [],
                dropdowns: [
                    "size": "Large",
                    "color": "Blue",
                    "machineType": "Excavator"
                ],
                dropdownSchemaVersion: 1,
                reasonsForService: ["Repair", "Maintenance", "Inspection"],
                reasonNotes: nil,
                completedReasons: [],
                statusHistory: [
                    WO_Status(status: "Checked In", user: "Tech", timestamp: Date().addingTimeInterval(-86400), notes: nil),
                    WO_Status(status: "In Progress", user: "Tech", timestamp: Date().addingTimeInterval(-3600), notes: "Started repair work")
                ],
                notes: [
                    WO_Note(
                        workOrderId: "preview-wo",
                        itemId: nil,
                        user: "Tech",
                        text: "Found worn seals, will need replacement",
                        timestamp: Date().addingTimeInterval(-1800),
                        imageUrls: []
                    )
                ],
                testResult: nil,
                partsUsed: nil,
                hoursWorked: nil,
                estimatedCost: nil,
                finalCost: nil,
                assignedTo: "Tech",
                isFlagged: false,
                tagReplacementHistory: nil
            ),
            WO_Item(
                id: UUID(),
                itemNumber: "250826-001-002",
                assetTagId: "TAG-67890",
                type: "Hydraulic Cylinder",
                imageUrls: ["https://picsum.photos/400/301"],
                thumbUrls: ["https://picsum.photos/100/101"],
                localImages: [],
                dropdowns: [
                    "size": "Medium",
                    "color": "Red"
                ],
                dropdownSchemaVersion: 1,
                reasonsForService: ["Inspection"],
                reasonNotes: nil,
                completedReasons: [],
                statusHistory: [
                    WO_Status(status: "Checked In", user: "Tech", timestamp: Date().addingTimeInterval(-7200), notes: nil)
                ],
                notes: [],
                testResult: nil,
                partsUsed: nil,
                hoursWorked: nil,
                estimatedCost: nil,
                finalCost: nil,
                assignedTo: "Tech",
                isFlagged: false,
                tagReplacementHistory: nil
            )
        ]
    )
    
    return FilteredWorkOrderDetailView(
        workOrder: sampleWorkOrder,
        scannedItem: sampleWorkOrder.items[0],
        scannedItemIndex: 0
    )
    .environmentObject(AppState.shared)
}
