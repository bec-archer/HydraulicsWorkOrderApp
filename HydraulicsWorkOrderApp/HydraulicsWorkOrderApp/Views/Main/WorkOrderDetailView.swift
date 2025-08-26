//
//  WorkOrderDetailView.swift
//  HydraulicsWorkOrderApp
//  Created by Bec Archer on 8/8/25.

import SwiftUI
import Foundation
import FirebaseStorage
import UIKit

// ───── WorkOrder Wrapper Class ─────
class WorkOrderWrapper: ObservableObject {
    @Published var wo: WorkOrder

    init(_ workOrder: WorkOrder) {
        self.wo = workOrder
    }
}
// END

struct WorkOrderDetailView: View {
    let workOrder: WorkOrder
    var onDelete: ((WorkOrder) -> Void)? = nil
    var onAddItemNote: ((WO_Item, WO_Note) -> Void)? = nil
    var onUpdateItemStatus: ((WO_Item, WO_Status, WO_Note) -> Void)? = nil
    
    @ObservedObject private var db = WorkOrdersDatabase.shared
    
    @StateObject private var woWrapper: WorkOrderWrapper
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var showDeleteConfirm = false
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL? = nil
    @State private var showingPhoneActions = false
    @State private var showingStatusPicker = false
    @State private var selectedItemForStatusUpdate: WO_Item? = nil
    @State private var showingAddNoteSheet = false
    @State private var selectedItemForNote: WO_Item? = nil
    
    private var canDelete: Bool {
#if DEBUG
        return true
#else
        return appState.canDeleteWorkOrders()
#endif
    }
    
    init(
        workOrder: WorkOrder,
        onDelete: ((WorkOrder) -> Void)? = nil,
        onAddItemNote: ((WO_Item, WO_Note) -> Void)? = nil,
        onUpdateItemStatus: ((WO_Item, WO_Status, WO_Note) -> Void)? = nil
    ) {
        self.workOrder = workOrder
        self.onDelete = onDelete
        self.onAddItemNote = onAddItemNote
        self.onUpdateItemStatus = onUpdateItemStatus
        _woWrapper = StateObject(wrappedValue: WorkOrderWrapper(workOrder))
    }
    
    // ───── MAIN BODY ─────
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // ───── Header Section ─────
                headerSection
                

                
                // ───── Work Order Items Section ─────
                itemsSection()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .onAppear {
            #if DEBUG
            print("🔍 WorkOrderDetailView: WorkOrder \(woWrapper.wo.WO_Number) has \(woWrapper.wo.items.count) items")
            for (i, item) in woWrapper.wo.items.enumerated() {
                print("  Item \(i): type='\(item.type)', images=\(item.imageUrls.count), thumbs=\(item.thumbUrls.count)")
            }
            if woWrapper.wo.items.isEmpty {
                print("⚠️ WorkOrderDetailView: No items found for work order \(woWrapper.wo.WO_Number)")
            }
            #endif
        }
        .sheet(isPresented: $showingPhoneActions) {
            PhoneActionSheet(
                customerName: woWrapper.wo.customerName,
                phoneNumber: woWrapper.wo.customerPhone,
                isPresented: $showingPhoneActions
            )
        }
        .sheet(isPresented: $showingStatusPicker) {
            if let item = selectedItemForStatusUpdate {
                StatusPickerSheet(
                    currentStatus: item.statusHistory.last?.status ?? "Checked In",
                    onStatusSelected: { newStatus in
                        updateItemStatus(item: item, newStatus: newStatus)
                        showingStatusPicker = false
                    },
                    isPresented: $showingStatusPicker
                )
            }
        }
        .sheet(isPresented: $showingAddNoteSheet) {
            if let item = selectedItemForNote {
                AddNoteSheet(
                    item: item,
                    onNoteAdded: { noteText, imageURLs in
                        addNoteToItem(item: item, noteText: noteText, imageURLs: imageURLs)
                        showingAddNoteSheet = false
                    },
                    isPresented: $showingAddNoteSheet
                )
            }
        }
        .navigationTitle("Work Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canDelete {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityLabel("Delete Work Order")
                }
            }
        }
        .alert("Delete this Work Order?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete?(workOrder)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the WorkOrder from Active. Managers/Admins can still access it in Deleted WorkOrders.")
        }
        .overlay {
            if showImageViewer, let url = selectedImageURL {
                FullScreenImageViewer(imageURL: url, isPresented: $showImageViewer)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)).animation(.easeOut(duration: 0.3)),
                        removal: .opacity.combined(with: .scale(scale: 1.1)).animation(.easeIn(duration: 0.2))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showImageViewer)
        .onChange(of: showImageViewer) { _, isShowing in
            if !isShowing {
                selectedImageURL = nil
            }
        }
    }
    
    // ───── Header Section ─────
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Left Column - Work Order Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Work Order #\(woWrapper.wo.WO_Number)")
                        .font(.largeTitle.bold())
                    
                    Text(woWrapper.wo.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Right Column - Customer Info
                VStack(alignment: .trailing, spacing: 4) {
                    Text(woWrapper.wo.customerName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let company = woWrapper.wo.customerCompany, !company.isEmpty {
                        Text(company)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                        Text(woWrapper.wo.customerPhone)
                            .underline()
                            .foregroundColor(Color(hex: "#FFC500"))
                            .onLongPressGesture {
                                showingPhoneActions = true
                            }
                    }
                    .accessibilityLabel("Call or text customer")
                    
                    if woWrapper.wo.customerTaxExempt {
                        Text("*Customer is tax exempt")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Flagged indicator (if needed)
            if woWrapper.wo.flagged {
                HStack {
                    Label("Flagged", systemImage: "flag.fill")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
    

    
    // ───── Work Order Items Section ─────
    @ViewBuilder
    private func itemsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WO Items")
                .font(.title3.weight(.semibold))
            
            #if DEBUG
            let _ = {
                print("🔍 WorkOrderDetailView: WorkOrder \(woWrapper.wo.WO_Number) has \(woWrapper.wo.items.count) items")
                if woWrapper.wo.items.isEmpty {
                    print("⚠️ WorkOrderDetailView: No items found for work order \(woWrapper.wo.WO_Number)")
                } else {
                    for (index, item) in woWrapper.wo.items.enumerated() {
                        print("  Item \(index): type='\(item.type)', images=\(item.imageUrls.count), thumbs=\(item.thumbUrls.count)")
                    }
                }
            }()
            #endif
            
            if woWrapper.wo.items.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Items Found")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("This work order doesn't have any items yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(Array(woWrapper.wo.items.enumerated()), id: \.element.id) { idx, item in
                    VStack(alignment: .leading, spacing: 10) {
                        let imageURLsBinding: Binding<[String]> = Binding(
                            get: { woWrapper.wo.items[idx].imageUrls },
                            set: { woWrapper.wo.items[idx].imageUrls = $0 }
                        )
                        let thumbURLsBinding: Binding<[String]> = Binding(
                            get: { woWrapper.wo.items[idx].thumbUrls },
                            set: { woWrapper.wo.items[idx].thumbUrls = $0 }
                        )
                        let handleImageTap: (URL) -> Void = { url in
                            selectedImageURL = url
                            DispatchQueue.main.async {
                                print("🧷 Will present viewer for: \(url.absoluteString)")
                                showImageViewer = true
                            }
                        }
                        let handleAddNote: (WO_Item, WO_Note) -> Void = { item, note in
                            if let itemIdx = woWrapper.wo.items.firstIndex(where: { $0.id == item.id }) {
                                woWrapper.wo.items[itemIdx].notes.append(note)
                                woWrapper.wo.lastModified = Date()
                                woWrapper.wo.lastModifiedBy = note.user

                                let woIdString = woWrapper.wo.id ?? ""
                                WorkOrdersDatabase.shared.addItemNote(
                                    woId: woIdString,
                                    itemId: item.id,
                                    note: note
                                ) { result in
                                    switch result {
                                    case .success:
                                        print("✅ Note saved for \(item.type) – images: \(note.imageURLs.count)")
                                    case .failure(let err):
                                        print("❌ Failed to save note: \(err.localizedDescription)")
                                    }
                                }
                            }
                            onAddItemNote?(item, note)
                        }
                        
                        self.combinedItemCard(
                            item: item,
                            itemIndex: idx,
                            imageURLsBinding: imageURLsBinding,
                            thumbURLsBinding: thumbURLsBinding,
                            handleImageTap: handleImageTap,
                            handleAddNote: handleAddNote
                        )
                    }
                }
            }
        }
    }
}

// ───── Helper Functions ─────

extension WorkOrderDetailView {
    private func handleNoteAddResult(_ result: Result<Void, Error>, item: WO_Item, note: WO_Note) {
        switch result {
        case .success:
            #if DEBUG
            print("✅ Note added for \(item.type) with \(note.imageURLs.count) images")
            #endif
            
            // Update local state immediately
            DispatchQueue.main.async {
                // Find the item in the local work order and add the note
                if let itemIndex = woWrapper.wo.items.firstIndex(where: { $0.id == item.id }) {
                    var updatedItem = woWrapper.wo.items[itemIndex]
                    updatedItem.notes.append(note)
                    
                    // Update the work order
                    var updatedWO = woWrapper.wo
                    updatedWO.items[itemIndex] = updatedItem
                    updatedWO.lastModified = Date()
                    updatedWO.lastModifiedBy = "Tech"
                    
                    woWrapper.wo = updatedWO
                    
                    #if DEBUG
                    print("🔄 Updated local state with new note for item \(item.type) with \(note.imageURLs.count) images")
                    print("   Note text: '\(note.text)'")
                    print("   Image URLs: \(note.imageURLs)")
                    #endif
                }
            }
            
        case .failure(let error):
            #if DEBUG
            print("❌ Failed to add note: \(error.localizedDescription)")
            #endif
        }
    }
    
    private func handleStatusUpdateResult(_ result: Result<Void, Error>, item: WO_Item, newStatus: String) {
        switch result {
        case .success:
            #if DEBUG
            print("✅ Status updated for \(item.type) to '\(newStatus)'")
            #endif
            
            // Update local state immediately
            DispatchQueue.main.async {
                // Find the item in the local work order and update its status
                if let itemIndex = woWrapper.wo.items.firstIndex(where: { $0.id == item.id }) {
                    var updatedItem = woWrapper.wo.items[itemIndex]
                    
                    // Add the new status to the history
                    let newStatusEntry = WO_Status(
                        status: newStatus,
                        user: "Tech",
                        timestamp: Date(),
                        notes: nil
                    )
                    updatedItem.statusHistory.append(newStatusEntry)
                    
                    // Add a note about the status change
                    let statusNote = WO_Note(
                        user: "Tech",
                        text: "Status changed to: \(newStatus)",
                        timestamp: Date(),
                        imageURLs: []
                    )
                    updatedItem.notes.append(statusNote)
                    
                    // Update the work order
                    var updatedWO = woWrapper.wo
                    updatedWO.items[itemIndex] = updatedItem
                    updatedWO.lastModified = Date()
                    updatedWO.lastModifiedBy = "Tech"
                    
                    woWrapper.wo = updatedWO
                    
                    #if DEBUG
                    print("🔄 Updated local state for item \(item.type) to status: \(newStatus)")
                    #endif
                }
            }
            
            // Notify parent view
            onUpdateItemStatus?(item, WO_Status(
                status: newStatus,
                user: "System",
                timestamp: Date()
            ), WO_Note(
                id: UUID(),
                user: "System",
                text: "Status changed to: \(newStatus)",
                timestamp: Date(),
                imageURLs: []
            ))
            
        case .failure(let error):
            #if DEBUG
            print("❌ Failed to update status: \(error.localizedDescription)")
            #endif
        }
    }
    
    // ───── Per‑Item Timeline Card (Notes + Status) ─────
    @ViewBuilder
    private func itemTimelineCard(for item: WO_Item) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes & Status")
                .font(.headline)
            
            // Status history entries
            if !item.statusHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(item.statusHistory.enumerated()), id: \.offset) { _, s in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(statusColor(for: s.status))
                                .padding(.top, 6)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.status)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(statusColor(for: s.status))
                                Text("\(s.user) • \(s.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            // Text notes
            if !item.notes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(item.notes.enumerated()), id: \.offset) { _, n in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.top, 3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatNoteText(n.text, item: item))
                                    .font(.subheadline)
                                Text("\(n.user) • \(n.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                // Note-attached images
                                if !n.imageURLs.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(Array(n.imageURLs.enumerated()), id: \.offset) { _, urlStr in
                                                if let url = URL(string: urlStr) {
                                                    Button {
                                                        selectedImageURL = url
                                                        DispatchQueue.main.async { showImageViewer = true }
                                                    } label: {
                                                        AsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .empty:
                                                                ProgressView().frame(width: 72, height: 72)
                                                            case .success(let img):
                                                                img.resizable().scaledToFill()
                                                                    .frame(width: 72, height: 72)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                            case .failure:
                                                                Color.gray.frame(width: 72, height: 72)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                            @unknown default:
                                                                EmptyView()
                                                            }
                                                        }
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gray.opacity(0.12))
        )
    }
    
    // ───── Reasons for Service Card ─────
    @ViewBuilder
    private func reasonsForServiceCard(for item: WO_Item, itemIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reasons for Service")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(item.reasonsForService, id: \.self) { reason in
                    let isCompleted = item.completedReasons.contains(reason)
                    
                    Button(action: {
                        toggleReasonCompletion(for: item, reason: reason, itemIndex: itemIndex)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                                .foregroundColor(isCompleted ? .green : .gray)
                                .font(.system(size: 16))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                // Display just "Other" instead of "Other (opens Service Notes)"
                                let displayText = reason.contains("(opens Service Notes)") ? "Other" : reason
                                Text(displayText)
                                    .font(.subheadline)
                                    .foregroundColor(isCompleted ? .secondary : .primary)
                                    .strikethrough(isCompleted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Show actual note content for "Other" reason
                                if reason.contains("Other") && !item.reasonNotes.isNilOrEmpty {
                                    Text(item.reasonNotes ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isCompleted ? Color(.systemGray6) : Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isCompleted ? Color.green.opacity(0.3) : Color(.systemGray4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gray.opacity(0.12))
        )
    }
    
    // ───── Toggle Reason Completion ─────
    private func toggleReasonCompletion(for item: WO_Item, reason: String, itemIndex: Int) {
        var updatedCompletedReasons = item.completedReasons
        
        if updatedCompletedReasons.contains(reason) {
            // Remove from completed
            updatedCompletedReasons.removeAll { $0 == reason }
        } else {
            // Add to completed
            updatedCompletedReasons.append(reason)
        }
        
        // Create completion note
        let timestamp = Date()
        let userName = "Joe" // TODO: Get actual user name from app state
        let checkmark = updatedCompletedReasons.contains(reason) ? "✅" : "❌"
        
        // Format the note text to show actual note content for "Other" reason
        let noteText: String
        if reason.contains("(opens Service Notes)") && !item.reasonNotes.isNilOrEmpty {
            noteText = "\(checkmark) Other: \(item.reasonNotes ?? "")"
        } else if reason.contains("(opens Service Notes)") {
            noteText = "\(checkmark) Other"
        } else {
            noteText = "\(checkmark) \(reason)"
        }
        
        let note = WO_Note(
            id: UUID(),
            user: userName,
            text: noteText,
            timestamp: timestamp,
            imageURLs: []
        )
        
        // Update local wrapper
        var updatedItem = woWrapper.wo.items[itemIndex]
        updatedItem.completedReasons = updatedCompletedReasons
        updatedItem.notes.append(note)
        
        var updatedWO = woWrapper.wo
        updatedWO.items[itemIndex] = updatedItem
        updatedWO.lastModified = timestamp
        updatedWO.lastModifiedBy = userName
        
        woWrapper.wo = updatedWO
        
        // Update Firestore
        let woIdString = woWrapper.wo.id
        
        if woIdString == nil || woIdString?.isEmpty == true {
            #if DEBUG
            print("⚠️ Work Order ID is empty, attempting to find by WO_Number: \(woWrapper.wo.WO_Number)")
            #endif
            
            // Try to get the document ID from Firestore
            db.findWorkOrderId(byWONumber: woWrapper.wo.WO_Number) { result in
                switch result {
                case .success(let foundId):
                    #if DEBUG
                    print("✅ Found Firestore ID for WO \(woWrapper.wo.WO_Number): \(foundId)")
                    #endif
                    
                    // Update completed reasons with found ID
                    WorkOrdersDatabase.shared.updateCompletedReasons(
                        woId: foundId,
                        itemId: item.id,
                        completedReasons: updatedCompletedReasons,
                        note: note
                    ) { result in
                        switch result {
                        case .success:
                            #if DEBUG
                            print("✅ Updated completed reasons for \(item.type): \(updatedCompletedReasons)")
                            #endif
                        case .failure(let error):
                            #if DEBUG
                            print("❌ Failed to update completed reasons: \(error.localizedDescription)")
                            #endif
                        }
                    }
                    
                case .failure(let error):
                    #if DEBUG
                    print("❌ Failed to find Firestore ID: \(error.localizedDescription)")
                    #endif
                }
            }
            return
        }
        
        #if DEBUG
        print("📝 Updating completed reasons for WO: \(woIdString ?? "nil"), Item: \(item.id)")
        print("   Completed reasons: \(updatedCompletedReasons)")
        #endif
        
        WorkOrdersDatabase.shared.updateCompletedReasons(
            woId: woIdString!,
            itemId: item.id,
            completedReasons: updatedCompletedReasons,
            note: note
        ) { result in
            switch result {
            case .success:
                #if DEBUG
                print("✅ Updated completed reasons for \(item.type): \(updatedCompletedReasons)")
                #endif
            case .failure(let error):
                #if DEBUG
                print("❌ Failed to update completed reasons: \(error.localizedDescription)")
                #endif
            }
        }
        
        // Post notification to trigger UI updates
        NotificationCenter.default.post(
            name: .WorkOrderSaved,
            object: woWrapper.wo.id,
            userInfo: ["WO_Number": woWrapper.wo.WO_Number]
        )
    }
    
    // ───── Combined Item Card (Item Details + Notes & Status) ─────
    @ViewBuilder
    private func combinedItemCard(
        item: WO_Item,
        itemIndex: Int,
        imageURLsBinding: Binding<[String]>,
        thumbURLsBinding: Binding<[String]>,
        handleImageTap: @escaping (URL) -> Void,
        handleAddNote: @escaping (WO_Item, WO_Note) -> Void
    ) -> some View {
                VStack(alignment: .leading, spacing: 16) {
            // Item Header
            HStack {
                Text(item.type)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack(alignment: .top, spacing: 16) {
                // Left Column - Item Details (responsive width)
                VStack(alignment: .leading, spacing: 12) {
                    // Main Image
                    if let firstImageURL = item.imageUrls.first, let url = URL(string: firstImageURL) {
                        Button {
                            handleImageTap(url)
                        } label: {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .aspectRatio(1, contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .aspectRatio(1, contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    Color.gray
                                        .aspectRatio(1, contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Thumbnail Images (additional images)
                    if item.imageUrls.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(item.imageUrls.dropFirst().enumerated()), id: \.offset) { _, imageURL in
                                    if let url = URL(string: imageURL) {
                                        Button {
                                            handleImageTap(url)
                                        } label: {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
                                                        .aspectRatio(1, contentMode: .fit)
                                                        .frame(width: 80, height: 80)
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .aspectRatio(1, contentMode: .fit)
                                                        .frame(width: 80, height: 80)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                case .failure:
                                                    Color.gray
                                                        .aspectRatio(1, contentMode: .fit)
                                                        .frame(width: 80, height: 80)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    
                    // Add Note/Image Button
                    Button {
                        selectedItemForNote = item
                        showingAddNoteSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Note/Image")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                
                // Right Column - Notes & Status
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Notes & Status")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Status Badge (Clickable)
                        if let lastStatus = item.statusHistory.last?.status {
                            Button {
                                selectedItemForStatusUpdate = item
                                showingStatusPicker = true
                            } label: {
                                Text(lastStatus)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColor(for: lastStatus).opacity(0.2))
                                    .foregroundColor(statusColor(for: lastStatus))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Combined timeline of status history and notes
                    VStack(alignment: .leading, spacing: 8) {
                        // Status history entries
                        ForEach(Array(item.statusHistory.enumerated()), id: \.offset) { _, status in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(statusColor(for: status.status))
                                    .padding(.top, 6)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(status.status)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(statusColor(for: status.status))
                                    Text("\(status.user) • \(status.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        // Text notes
                        ForEach(Array(item.notes.enumerated()), id: \.offset) { _, note in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatNoteText(note.text, item: item))
                                        .font(.subheadline)
                                    Text("\(note.user) • \(note.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    // Note-attached images
                                    if !note.imageURLs.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(Array(note.imageURLs.enumerated()), id: \.offset) { _, urlStr in
                                                    if let url = URL(string: urlStr) {
                                                        Button {
                                                            handleImageTap(url)
                                                        } label: {
                                                            AsyncImage(url: url) { phase in
                                                                switch phase {
                                                                case .empty:
                                                                    ProgressView()
                                                                        .aspectRatio(1, contentMode: .fit)
                                                                        .frame(width: 80, height: 80)
                                                                case .success(let img):
                                                                    img.resizable().scaledToFill()
                                                                        .aspectRatio(1, contentMode: .fit)
                                                                        .frame(width: 80, height: 80)
                                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                                case .failure:
                                                                    Color.gray
                                                                        .aspectRatio(1, contentMode: .fit)
                                                                        .frame(width: 80, height: 80)
                                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                                @unknown default:
                                                                    EmptyView()
                                                                }
                                                            }
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            
            // Reasons for Service Section (if exists)
            if !item.reasonsForService.isEmpty {
                self.reasonsForServiceCard(for: item, itemIndex: itemIndex)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gray.opacity(0.12))
        )
    }
    
    // ───── Format Note Text Helper ─────
    private func formatNoteText(_ noteText: String, item: WO_Item) -> String {
        if noteText.contains("Other (opens Service Notes)") && !item.reasonNotes.isNilOrEmpty {
            return noteText.replacingOccurrences(of: "Other (opens Service Notes)", with: "Other: \(item.reasonNotes ?? "")")
        } else if noteText.contains("Other (opens Service Notes)") {
            return noteText.replacingOccurrences(of: "Other (opens Service Notes)", with: "Other")
        } else {
            return noteText
        }
    }
    
    // ───── Add Note Helper ─────
    private func addNoteToItem(item: WO_Item, noteText: String, imageURLs: [String]) {
        print("📝 Adding note to item \(item.type): text='\(noteText)', imageURLs=\(imageURLs)")
        let note = WO_Note(
            user: "Tech",
            text: noteText,
            timestamp: Date(),
            imageURLs: imageURLs
        )
        
        // Check if we have a valid work order ID
        if let woId = woWrapper.wo.id, !woId.isEmpty {
            print("🔄 Adding note to WO \(woWrapper.wo.WO_Number) with ID: \(woId)")
            
            WorkOrdersDatabase.shared.addItemNote(
                woId: woId,
                itemId: item.id,
                note: note
            ) { result in
                handleNoteAddResult(result, item: item, note: note)
            }
        } else {
            print("⚠️ Work Order ID is empty, attempting to find by WO_Number: \(woWrapper.wo.WO_Number)")
            
            // Try to get the document ID from Firestore using WO_Number
            WorkOrdersDatabase.shared.findWorkOrderId(byWONumber: woWrapper.wo.WO_Number) { result in
                switch result {
                case .success(let foundId):
                    print("✅ Found Firestore ID for WO \(woWrapper.wo.WO_Number): \(foundId)")
                    
                    WorkOrdersDatabase.shared.addItemNote(
                        woId: foundId,
                        itemId: item.id,
                        note: note
                    ) { result in
                        handleNoteAddResult(result, item: item, note: note)
                    }
                    
                case .failure(let error):
                    print("❌ Failed to find Firestore ID: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // ───── Status Update Helper ─────
    private func updateItemStatus(item: WO_Item, newStatus: String) {
        let status = WO_Status(
            status: newStatus,
            user: "Tech",
            timestamp: Date(),
            notes: nil
        )
        
        let note = WO_Note(
            user: "Tech",
            text: "Status changed to: \(newStatus)",
            timestamp: Date(),
            imageURLs: []
        )
        
        // Check if we have a valid work order ID
        if let woId = woWrapper.wo.id, !woId.isEmpty {
            print("🔄 Updating status for WO \(woWrapper.wo.WO_Number) with ID: \(woId)")
            
            WorkOrdersDatabase.shared.updateItemStatusAndNote(
                woId: woId,
                itemId: item.id,
                status: status,
                mirroredNote: note
            ) { result in
                handleStatusUpdateResult(result, item: item, newStatus: newStatus)
            }
        } else {
            print("⚠️ Work Order ID is empty, attempting to find by WO_Number: \(woWrapper.wo.WO_Number)")
            
            // Try to get the document ID from Firestore using WO_Number
            WorkOrdersDatabase.shared.findWorkOrderId(byWONumber: woWrapper.wo.WO_Number) { result in
                switch result {
                case .success(let foundId):
                    print("✅ Found Firestore ID for WO \(woWrapper.wo.WO_Number): \(foundId)")
                    
                    WorkOrdersDatabase.shared.updateItemStatusAndNote(
                        woId: foundId,
                        itemId: item.id,
                        status: status,
                        mirroredNote: note
                    ) { result in
                        handleStatusUpdateResult(result, item: item, newStatus: newStatus)
                    }
                    
                case .failure(let error):
                    print("❌ Failed to find Firestore ID: \(error.localizedDescription)")
                    // Show user feedback that the update failed
                    DispatchQueue.main.async {
                        // You could add a @State variable to show an alert here
                        print("❌ Status update failed - could not find work order in database")
                    }
                }
            }
        }
    }
    
    // ───── Status Color Helper ─────
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "checked in":       return UIConstants.StatusColors.checkedIn
        case "disassembly":      return UIConstants.StatusColors.disassembly
        case "in progress":      return UIConstants.StatusColors.inProgress
        case "test failed":      return UIConstants.StatusColors.testFailed
        case "completed":        return UIConstants.StatusColors.completed
        case "closed":           return UIConstants.StatusColors.closed
        case "done":             return UIConstants.StatusColors.completed
        case "tested: pass":     return UIConstants.StatusColors.completed
        case "tested: fail":     return UIConstants.StatusColors.testFailed
        default:                 return UIConstants.StatusColors.fallback
        }
    }
}

// MARK: - String Extension
extension String? {
    var isNilOrEmpty: Bool {
        return self?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
}

// MARK: - PhoneActionSheet
struct PhoneActionSheet: View {
    let customerName: String
    let phoneNumber: String
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Contact \(customerName)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Choose how to contact \(customerName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Call Button
                    Button {
                        let phoneNumberDigits = phoneNumber.filter(\.isNumber)
                        let telURL = URL(string: "tel://\(phoneNumberDigits)")
                        
                        #if DEBUG
                        print("📞 Phone call selected - Number: \(phoneNumberDigits)")
                        print("📞 Phone call selected - URL: \(telURL?.absoluteString ?? "invalid URL")")
                        #endif
                        
                        if let telURL = telURL {
                            openURL(telURL) { success in
                                if !success {
                                    #if DEBUG
                                    print("❌ Failed to open phone URL - this is expected in Simulator")
                                    #endif
                                    
                                    // Copy number to clipboard as fallback
                                    UIPasteboard.general.string = phoneNumberDigits
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                }
                            }
                        }
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.white)
                            Text("Call \(phoneNumber)")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Text Button
                    Button {
                        let phoneNumberDigits = phoneNumber.filter(\.isNumber)
                        let smsURL = URL(string: "sms://\(phoneNumberDigits)")
                        
                        #if DEBUG
                        print("💬 Text selected - Number: \(phoneNumberDigits)")
                        print("💬 Text selected - URL: \(smsURL?.absoluteString ?? "invalid URL")")
                        #endif
                        
                        if let smsURL = smsURL {
                            openURL(smsURL) { success in
                                if !success {
                                    #if DEBUG
                                    print("❌ Failed to open SMS URL - this is expected in Simulator")
                                    #endif
                                    
                                    // Copy number to clipboard as fallback
                                    UIPasteboard.general.string = phoneNumberDigits
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                }
                            }
                        }
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: "message.fill")
                                .foregroundColor(.white)
                            Text("Text \(phoneNumber)")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Copy Button
                    Button {
                        let phoneNumberDigits = phoneNumber.filter(\.isNumber)
                        UIPasteboard.general.string = phoneNumberDigits
                        
                        #if DEBUG
                        print("📋 Phone number copied to clipboard: \(phoneNumberDigits)")
                        #endif
                        
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc.fill")
                                .foregroundColor(.primary)
                            Text("Copy Number")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// ───── Status Picker Sheet ─────
struct StatusPickerSheet: View {
    let currentStatus: String
    let onStatusSelected: (String) -> Void
    @Binding var isPresented: Bool
    
    private let statusOptions = [
        "Checked In",
        "Disassembly", 
        "In Progress",
        "Test Failed",
        "Completed",
        "Closed"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Status")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(spacing: 12) {
                    ForEach(statusOptions, id: \.self) { status in
                        Button {
                            onStatusSelected(status)
                        } label: {
                            HStack {
                                Text(status)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if status == currentStatus {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(status == currentStatus ? Color.blue.opacity(0.1) : Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(status == currentStatus ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// ───── Add Note Sheet ─────
struct AddNoteSheet: View {
    let item: WO_Item
    let onNoteAdded: (String, [String]) -> Void
    @Binding var isPresented: Bool
    
    @State private var noteText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isUploading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Note")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 16) {
                    // Note Text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.headline)
                        
                        TextEditor(text: $noteText)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Image Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Images (Optional)")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            Button {
                                showingCamera = true
                            } label: {
                                VStack {
                                    Image(systemName: "camera")
                                        .font(.title2)
                                    Text("Camera")
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 80)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            Button {
                                showingImagePicker = true
                            } label: {
                                VStack {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title2)
                                    Text("Gallery")
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 80)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Selected Images Preview
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            
                                            Button {
                                                selectedImages.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .background(Color.white)
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 5, y: -5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button(isUploading ? "Uploading..." : "Add Note") {
                        if selectedImages.isEmpty {
                            // No images to upload, just add the note
                            onNoteAdded(noteText, [])
                            isPresented = false
                        } else {
                            // Upload images first, then add note
                            uploadImagesAndAddNote(noteText: noteText, images: selectedImages)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled((noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImages.isEmpty) || isUploading)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCamera) {
                ImagePicker(selectedImage: Binding(
                    get: { nil },
                    set: { image in
                        if let image = image {
                            selectedImages.append(image)
                        }
                    }
                ), sourceType: .camera)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: Binding(
                    get: { nil },
                    set: { image in
                        if let image = image {
                            selectedImages.append(image)
                        }
                    }
                ), sourceType: .photoLibrary)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private func uploadImagesAndAddNote(noteText: String, images: [UIImage]) {
        isUploading = true
        
        // Generate a unique folder name for this note's images
        let noteId = UUID().uuidString
        let timestamp = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timeString = dateFormatter.string(from: timestamp)
        
        var uploadedURLs: [String] = []
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "imageUpload", attributes: .concurrent)
        
        for (index, image) in images.enumerated() {
            group.enter()
            
            // Generate filename
            let filename = "\(timeString)_\(index).jpg"
            // Use the same path structure as original images: intake/{itemId}/{noteId}/{filename}
            let path = "intake/\(item.id)/\(noteId)/\(filename)"
            
            // Compress image
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                group.leave()
                continue
            }
            
            // Upload to Firebase Storage
            let storageRef = Storage.storage().reference().child(path)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            storageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    print("❌ Failed to upload image \(index): \(error.localizedDescription)")
                    group.leave()
                    return
                }
                
                // Get download URL
                storageRef.downloadURL { url, error in
                    defer { group.leave() }
                    
                    if let downloadURL = url {
                        queue.async(flags: .barrier) {
                            uploadedURLs.append(downloadURL.absoluteString)
                        }
                        print("✅ Uploaded image \(index): \(downloadURL.absoluteString)")
                    } else {
                        print("❌ Failed to get download URL for image \(index)")
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            self.isUploading = false
            print("📸 Upload complete. Note text: '\(noteText)', Image URLs: \(uploadedURLs)")
            self.onNoteAdded(noteText, uploadedURLs)
            self.isPresented = false
        }
    }
}

// ───── Image Picker ─────
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// ───── Preview Template ─────
#Preview {
    WorkOrderDetailView(
        workOrder: WorkOrder(
            id: UUID().uuidString,
            createdBy: "Preview User",
            customerId: "preview-customer-id",
            customerName: "Maria Hydraulic",
            customerPhone: "555-1212",
            WO_Type: "Pump",
            imageURL: nil,
            timestamp: Date(),
            status: "Checked In",
            WO_Number: "250818-001",
            flagged: true,
            tagId: nil,
            estimatedCost: nil,
            finalCost: nil,
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            lastModified: Date(),
            lastModifiedBy: "Preview User",
            tagBypassReason: nil,
            isDeleted: false,
            notes: [],
            items: []
        ),
        onDelete: nil,
        onAddItemNote: nil,
        onUpdateItemStatus: nil
    )
    .environmentObject(AppState.shared)
}
