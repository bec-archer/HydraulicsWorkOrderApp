//
//  WorkOrderDetailView.swift
//  HydraulicsWorkOrderApp
//  Created by Bec Archer on 8/8/25.

import SwiftUI
import Foundation
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
                        
                        ItemCard(
                            item: item,
                            imageURLs: imageURLsBinding,
                            thumbURLs: thumbURLsBinding,
                            woId: (woWrapper.wo.id ?? ""),
                            onImageTap: handleImageTap,
                            onAddNote: handleAddNote,
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
                        
                        itemTimelineCard(for: item)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 0)
                }
            }
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
