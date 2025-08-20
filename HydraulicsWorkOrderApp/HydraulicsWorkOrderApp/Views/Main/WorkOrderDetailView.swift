//  WorkOrderDetailView.swift
//  HydraulicsWorkOrderApp
//  Created by Bec Archer on 8/8/25.

import SwiftUI
import Foundation

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
    
    @StateObject private var woWrapper: WorkOrderWrapper
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var showDeleteConfirm = false
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL? = nil
    
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
                // NOTE: These are functions annotated with @ViewBuilder, so we must CALL them.
                // Using the identifier without parentheses can lead to ambiguous type errors in ViewBuilder contexts.
                itemsSection()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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
        } // END toolbar
        .alert("Delete this Work Order?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete?(workOrder)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the WorkOrder from Active. Managers/Admins can still access it in Deleted WorkOrders.")
        } // END alert
        .fullScreenCover(isPresented: $showImageViewer) {
            // Force a single erased return type to silence ambiguous init
            if let url = selectedImageURL {
                AnyView(
                    FullScreenImageViewer(imageURL: url, isPresented: $showImageViewer)
                )
            } else {
                AnyView(
                    Color.black.overlay(
                        Text("❌ No image to show")
                            .foregroundColor(.white)
                    )
                )
            }
        }
        
        .onChange(of: showImageViewer) { isShowing in
            if !isShowing {
                // Clear selection so the next tap always sets a fresh URL
                selectedImageURL = nil
            }
        }
        
    } // END body
    
    // ───── Header Section Extracted ─────
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("WO #\(woWrapper.wo.WO_Number)")
                    .font(.largeTitle.bold())
                StatusBadge(status: woWrapper.wo.status.isEmpty ? "Checked In" : woWrapper.wo.status)
            }
            
            Text(woWrapper.wo.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                    Button {
                        let digitsOnlyPhone = woWrapper.wo.customerPhone.filter(\.isNumber)
                        if let telURL = URL(string: "tel://\(digitsOnlyPhone)") {
                            UIApplication.shared.open(telURL)
                        }
                    } label: {
                        Text(woWrapper.wo.customerPhone)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color(hex: "#FFC500"))
                    .contextMenu {
                        Button("Text") {
                            let digitsOnlyPhone = woWrapper.wo.customerPhone.filter(\.isNumber)
                            if let smsURL = URL(string: "sms:\(digitsOnlyPhone)") {
                                UIApplication.shared.open(smsURL)
                            }
                        }
                    }
                }
                .accessibilityLabel("Call or text customer")
                
                if woWrapper.wo.flagged {
                    Label("Flagged", systemImage: "flag.fill")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
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
    
    // ───── Work Order Items Section Extracted ─────
    @ViewBuilder
    private func itemsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WO Items")
                .font(.title3.weight(.semibold))
            
            // ───── Per‑Item Cards ─────
            ForEach(woWrapper.wo.items) { item in
                VStack(alignment: .leading, spacing: 10) {
                    // ItemCard for each WO_Item (full‑width)
                    if let idx = woWrapper.wo.items.firstIndex(where: { $0.id == item.id }) {
                        ItemCard(
                            item: item,
                            imageURLs: Binding(
                                get: { woWrapper.wo.items[idx].imageUrls },
                                set: { woWrapper.wo.items[idx].imageUrls = $0 }
                            ),
                            thumbURLs: Binding(
                                get: { woWrapper.wo.items[idx].thumbUrls },
                                set: { woWrapper.wo.items[idx].thumbUrls = $0 }
                            ),
                            woId: woWrapper.wo.id,
                            onImageTap: { url in
                                selectedImageURL = url
                                DispatchQueue.main.async {
                                    print("🧷 Will present viewer for: \(url.absoluteString)")
                                    showImageViewer = true
                                }
                            },
                            onAddNote: { item, note in
                                // Append to the correct WO_Item in-memory
                                if let noteIdx = woWrapper.wo.items.firstIndex(where: { $0.id == item.id }) {
                                    woWrapper.wo.items[noteIdx].notes.append(note)
                                    woWrapper.wo.lastModified = Date()
                                    woWrapper.wo.lastModifiedBy = note.user
                                    
                                    // Persist to your DB; assumes database layer accepts note.imageURLs
                                    WorkOrdersDatabase.shared.addItemNote(
                                        woId: woWrapper.wo.id ?? "",
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
                                // Bubble to any external listener if provided
                                onAddItemNote?(item, note)
                            },
                            onChangeStatus: { item, newStatus in
                                /* unchanged */
                            }
                        )
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.gray.opacity(0.1))
                        )
                        
                        // ───── Per‑Item Notes & Status Timeline ─────
                        itemTimelineCard(for: item)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 0)
            }
            // ───── END Per‑Item Cards ─────
        }
    } // END itemsSection()
    
    
    // ───── Global Notes Timeline Section ─────
    @ViewBuilder
    private func notesSection() -> some View {
        // 1) Synthesize a first entry that always shows the check‑in event
        let checkInAuthor = woWrapper.wo.createdBy
        let checkInTime   = woWrapper.wo.timestamp
        let checkInNote   = WO_Note(
            id: UUID(),
            user: checkInAuthor,
            text: "Checked In by \(checkInAuthor) at \(checkInTime.formatted(date: .abbreviated, time: .shortened))",
            timestamp: checkInTime
        )
        
        // 2) Combine with all WO_Item notes (already per‑item)
        let itemNotes = woWrapper.wo.items.flatMap { $0.notes }
        let timeline  = [checkInNote] + itemNotes
        
        NotesTimelineView(notes: timeline)
            .padding(.top, 12)
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
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.status)
                                    .font(.subheadline.weight(.semibold))
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
                                Text(n.text)
                                    .font(.subheadline)
                                Text("\(n.user) • \(n.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                // ───── Note-attached images (from WO_Note.imageURLs) ─────
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
                                        .padding(.top, 4)
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
        .padding(.top, 8)
    }
    
    // ───── Per‑Item Images Card (Thumbnails) ─────
    @ViewBuilder
    private func itemImagesCard(for item: WO_Item) -> some View {
        if !item.thumbUrls.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Images")
                    .font(.headline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(item.thumbUrls.enumerated()), id: \.offset) { idx, thumb in
                            if let thumbURL = URL(string: thumb) {
                                Button {
                                    // Prefer matching full‑size URL at same index; fallback to thumb
                                    let target = (item.imageUrls.indices.contains(idx) ? item.imageUrls[idx] : thumb)
                                    if let fullURL = URL(string: target) {
                                        selectedImageURL = fullURL
                                        DispatchQueue.main.async {
                                            showImageViewer = true
                                        }
                                    }
                                } label: {
                                    AsyncImage(url: thumbURL) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView().frame(width: 96, height: 96)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 96, height: 96)
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        case .failure:
                                            Color.gray
                                                .frame(width: 96, height: 96)
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.gray.opacity(0.12))
            )
        }
    }
    
    
    // ───── Preview Template ─────
    
    
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
    // END
}
