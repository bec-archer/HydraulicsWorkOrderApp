//
//  WorkOrderItemDetailView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Assistant on 1/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderItemDetailView.swift
// Individual work order item detail view for tag scanning navigation
// ─────────────────────────────────────────────────────────────

import SwiftUI
import Foundation

// MARK: - WorkOrderItemDetailView
struct WorkOrderItemDetailView: View {
    // MARK: - Properties
    let workOrder: WorkOrder
    let item: WO_Item
    let itemIndex: Int
    
    // MARK: - Environment
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel
    @StateObject private var viewModel: WorkOrderDetailViewModel
    
    // MARK: - State
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL?
    @State private var showStatusSelection = false
    @State private var showAddNotes = false
    @State private var showGallery = false
    
    // MARK: - Initialization
    init(workOrder: WorkOrder, item: WO_Item, itemIndex: Int) {
        self.workOrder = workOrder
        self.item = item
        self.itemIndex = itemIndex
        self._viewModel = StateObject(wrappedValue: WorkOrderDetailViewModel(workOrder: workOrder))
    }
    
    // MARK: - Computed Properties
    private var itemDisplayName: String {
        "\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))"
    }
    
    private var currentStatus: String {
        if itemIndex < viewModel.workOrder.items.count {
            return viewModel.workOrder.items[itemIndex].statusHistory.last?.status ?? "Checked In"
        } else {
            return item.statusHistory.last?.status ?? "Checked In"
        }
    }
    
    private var currentItem: WO_Item {
        // Safety check to ensure we have the right item
        if itemIndex < viewModel.workOrder.items.count {
            return viewModel.workOrder.items[itemIndex]
        } else {
            // Fallback to the original item if index is out of bounds
            print("⚠️ DEBUG: Item index \(itemIndex) out of bounds, using original item")
            return item
        }
    }
    
    // MARK: - Body
    var body: some View {
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
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    appState.navigateToView(.activeWorkOrders)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Change Status") {
                        showStatusSelection = true
                    }
                    
                    Button("Add Notes") {
                        showAddNotes = true
                    }
                    
                    Button("View Work Order") {
                        appState.navigateToWorkOrderDetail(workOrder)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showStatusSelection) {
            StatusSelectionView(
                currentStatus: currentStatus,
                onStatusSelected: { newStatus in
                    Task {
                        await viewModel.updateItemStatus(newStatus, for: itemIndex)
                        showStatusSelection = false
                    }
                }
            )
        }
        .sheet(isPresented: $showAddNotes) {
            AddNotesView(
                workOrder: workOrder,
                item: currentItem,
                itemIndex: itemIndex,
                onNotesAdded: { noteText, images in
                    Task {
                        await viewModel.addItemNoteWithImages(noteText, images: images, to: itemIndex)
                        showAddNotes = false
                    }
                }
            )
        }
        .sheet(isPresented: $showGallery) {
            ImageGalleryView(images: currentItem.imageUrls, title: itemDisplayName)
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let imageURL = selectedImageURL {
                FullScreenImageViewer(imageURL: imageURL, isPresented: $showImageViewer)
            }
        }
        .onAppear {
            print("🔍 DEBUG: WorkOrderItemDetailView appeared for item index: \(itemIndex)")
            print("🔍 DEBUG: Work order: \(workOrder.workOrderNumber)")
            print("🔍 DEBUG: Item type: \(item.type)")
            print("🔍 DEBUG: Total items in work order: \(workOrder.items.count)")
            // Ensure we have the latest work order data
            Task {
                await viewModel.refreshWorkOrder()
            }
        }
    }
    
    // MARK: - Item Header Card
    private var itemHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(itemDisplayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    
                    Text(currentItem.type.isEmpty ? "Item" : currentItem.type)
                        .font(.subheadline)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                }
                
                Spacer()
                
                // Status Badge
                Button(action: {
                    showStatusSelection = true
                }) {
                    StatusBadge(status: currentStatus)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Asset Tag ID
            if let tagId = currentItem.assetTagId {
                HStack {
                    Text("Asset Tag:")
                        .font(.subheadline)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                    Text(tagId)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    Spacer()
                }
            }
            
            // Work Order Reference
            HStack {
                Text("Work Order:")
                    .font(.subheadline)
                    .foregroundColor(ThemeManager.shared.textSecondary)
                Button(workOrder.workOrderNumber) {
                    appState.navigateToWorkOrderDetail(workOrder)
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ThemeManager.shared.linkColor)
                Spacer()
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
    }
    
    // MARK: - Item Images Section
    private var itemImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Images")
                    .font(.headline)
                    .foregroundColor(ThemeManager.shared.textPrimary)
                
                Spacer()
                
                if currentItem.imageUrls.count > 1 {
                    Button("View All") {
                        showGallery = true
                    }
                    .font(.subheadline)
                    .foregroundColor(ThemeManager.shared.linkColor)
                }
            }
            
            if currentItem.imageUrls.isEmpty {
                Text("No images available")
                    .font(.subheadline)
                    .foregroundColor(ThemeManager.shared.textSecondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                // Primary image
                if let firstImageURL = currentItem.imageUrls.first {
                    AsyncImage(url: URL(string: firstImageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(ThemeManager.shared.cardCornerRadius)
                            .onTapGesture {
                                selectedImageURL = URL(string: firstImageURL)
                                showImageViewer = true
                            }
                    } placeholder: {
                        Rectangle()
                            .fill(ThemeManager.shared.border.opacity(0.3))
                            .frame(height: 200)
                            .cornerRadius(ThemeManager.shared.cardCornerRadius)
                            .overlay(ProgressView())
                    }
                }
                
                // Thumbnail grid for additional images
                if currentItem.imageUrls.count > 1 {
                    let thumbnails = Array(currentItem.imageUrls.dropFirst())
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 80), spacing: 8)
                    ], spacing: 8) {
                        ForEach(Array(thumbnails.prefix(6).enumerated()), id: \.offset) { _, imageURL in
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        selectedImageURL = URL(string: imageURL)
                                        showImageViewer = true
                                    }
                            } placeholder: {
                                Rectangle()
                                    .fill(ThemeManager.shared.border.opacity(0.3))
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                            }
                        }
                        
                        // Show "+X more" if there are more than 7 total images
                        if currentItem.imageUrls.count > 7 {
                            Button(action: {
                                showGallery = true
                            }) {
                                ZStack {
                                    Rectangle()
                                        .fill(ThemeManager.shared.border.opacity(0.3))
                                        .frame(width: 80, height: 80)
                                        .cornerRadius(8)
                                    
                                    Text("+\(currentItem.imageUrls.count - 7)")
                                        .font(.headline)
                                        .foregroundColor(ThemeManager.shared.textPrimary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
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
    }
    
    // MARK: - Item Details Section
    private var itemDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Item Details")
                .font(.headline)
                .foregroundColor(ThemeManager.shared.textPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                // Reasons for Service
                if !currentItem.reasonsForService.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reasons for Service:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ThemeManager.shared.textPrimary)
                        
                        ForEach(currentItem.reasonsForService, id: \.self) { reason in
                            HStack {
                                Image(systemName: isReasonPerformed(reason) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(isReasonPerformed(reason) ? .green : ThemeManager.shared.textSecondary)
                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundColor(ThemeManager.shared.textPrimary)
                                Spacer()
                            }
                        }
                    }
                }
                
                // Dropdown details
                if !currentItem.dropdowns.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Details:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ThemeManager.shared.textPrimary)
                        
                        ForEach(Array(currentItem.dropdowns.keys.sorted()), id: \.self) { key in
                            if let value = currentItem.dropdowns[key], !value.isEmpty {
                                HStack {
                                    Text("\(key.capitalized):")
                                        .font(.subheadline)
                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                    Text(value)
                                        .font(.subheadline)
                                        .foregroundColor(ThemeManager.shared.textPrimary)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
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
    }
    
    // MARK: - Status & Notes Section
    private var statusAndNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status & Notes")
                .font(.headline)
                .foregroundColor(ThemeManager.shared.textPrimary)
            
            // Status History
            VStack(alignment: .leading, spacing: 8) {
                Text("Status History:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeManager.shared.textPrimary)
                
                if currentItem.statusHistory.isEmpty {
                    HStack {
                        Text("•")
                            .foregroundColor(ThemeManager.shared.textSecondary)
                        Text("Checked In")
                            .font(.subheadline)
                            .foregroundColor(ThemeManager.shared.textPrimary)
                        Spacer()
                        Text("System")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.textSecondary)
                    }
                } else {
                    ForEach(currentItem.statusHistory.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { status in
                        HStack {
                            Text("•")
                                .foregroundColor(ThemeManager.shared.textSecondary)
                            Text(status.status)
                                .font(.subheadline)
                                .foregroundColor(getStatusColor(status.status))
                            Spacer()
                            Text(status.user)
                                .font(.caption)
                                .foregroundColor(ThemeManager.shared.textSecondary)
                        }
                    }
                }
            }
            
            // Notes
            if !currentItem.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    
                    ForEach(currentItem.notes.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            if !note.text.isEmpty {
                                reasonServiceNoteText(note.text)
                            }
                            
                            HStack {
                                Text(note.user)
                                    .font(.caption)
                                    .foregroundColor(ThemeManager.shared.textSecondary)
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(ThemeManager.shared.textSecondary)
                                Text(note.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                    .font(.caption)
                                    .foregroundColor(ThemeManager.shared.textSecondary)
                                Spacer()
                            }
                        }
                    }
                }
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
    }
    
    // MARK: - Helper Methods
    private func isReasonPerformed(_ reason: String) -> Bool {
        let expectedStatus = "Service Performed — \(reason)"
        return currentItem.statusHistory.contains { status in
            status.status == expectedStatus
        }
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
                        .font(.subheadline)
                    Text(reasonText)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                }
            } else {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(ThemeManager.shared.textPrimary)
            }
        } else {
            Text(text)
                .font(.subheadline)
                .foregroundColor(ThemeManager.shared.textPrimary)
        }
    }
}


// MARK: - Preview
#Preview {
    WorkOrderItemDetailView(
        workOrder: WorkOrder(
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
            items: []
        ),
        item: WO_Item(
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
        itemIndex: 0
    )
    .environmentObject(AppState.shared)
}
