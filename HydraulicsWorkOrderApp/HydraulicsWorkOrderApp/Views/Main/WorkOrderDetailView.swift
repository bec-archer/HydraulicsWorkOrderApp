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
    
    @ObservedObject private var db = WorkOrdersDatabase.shared
    
    @StateObject private var woWrapper: WorkOrderWrapper
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var showDeleteConfirm = false
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL? = nil
    @State private var showingPhoneActions = false
    
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
        .sheet(isPresented: $showingPhoneActions) {
            PhoneActionSheet(
                customerName: woWrapper.wo.customerName,
                phoneNumber: woWrapper.wo.customerPhone,
                isPresented: $showingPhoneActions
            )
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
                    Text(woWrapper.wo.customerPhone)
                        .underline()
                        .foregroundColor(Color(hex: "#FFC500"))
                        .onLongPressGesture {
                            showingPhoneActions = true
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
                        
                        VStack(spacing: 16) {
                            ItemCard(
                                item: item,
                                imageURLs: imageURLsBinding,
                                thumbURLs: thumbURLsBinding,
                                woId: (woWrapper.wo.id ?? ""),
                                onImageTap: handleImageTap,
                                onAddNote: handleAddNote,
                                onChangeStatus: { item, newStatus in
                                // Find the item in our wrapper
                                if let itemIdx = woWrapper.wo.items.firstIndex(where: { $0.id == item.id }) {
                                    // Create status update objects
                                    let timestamp = Date()
                                    let userName = "System"
                                    
                                    let statusUpdate = WO_Status(
                                        status: newStatus,
                                        user: userName,
                                        timestamp: timestamp
                                    )
                                    
                                    // Create a status update note
                                    let note = WO_Note(
                                        id: UUID(),
                                        user: userName,
                                        text: "Status changed to: \(newStatus)",
                                        timestamp: timestamp,
                                        imageURLs: []
                                    )
                                    
                                    // Update item status history
                                    var updatedItem = woWrapper.wo.items[itemIdx]
                                    updatedItem.statusHistory.append(statusUpdate)
                                    updatedItem.notes.append(note)
                                    
                                    // Update work order
                                    var updatedWO = woWrapper.wo
                                    updatedWO.items[itemIdx] = updatedItem
                                    updatedWO.lastModified = timestamp
                                    updatedWO.lastModifiedBy = userName
                                    
                                    #if DEBUG
                                    print("🔄 WorkOrderDetailView: Updated work order \(updatedWO.WO_Number)")
                                    print("   - Item \(itemIdx): \(updatedItem.type) status changed to '\(newStatus)'")
                                    print("   - Total items: \(updatedWO.items.count)")
                                    for (idx, item) in updatedWO.items.enumerated() {
                                        print("     Item \(idx): \(item.type) - images: \(item.imageUrls.count), thumbs: \(item.thumbUrls.count)")
                                    }
                                    #endif
                                    
                                    // Update local wrapper
                                    woWrapper.wo = updatedWO
                                    
                                    // Post notification to trigger UI updates
                                    NotificationCenter.default.post(
                                        name: .WorkOrderSaved,
                                        object: updatedWO.id,
                                        userInfo: ["WO_Number": updatedWO.WO_Number]
                                    )
                                    
                                    // Update Firestore
                                    // Try to find the work order by WO_Number if id is missing
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
                                                
                                                // Update status with found ID
                                                WorkOrdersDatabase.shared.updateItemStatusAndNote(
                                                    woId: foundId,
                                                    itemId: item.id,
                                                    status: statusUpdate,
                                                    mirroredNote: note) { result in
                                                        self.handleStatusUpdateResult(result, item: item, newStatus: newStatus)
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
                                    print("📝 Updating status for WO: \(woIdString ?? "nil"), Item: \(item.id)")
                                    print("   New Status: \(newStatus)")
                                    #endif
                                    
                                    WorkOrdersDatabase.shared.updateItemStatusAndNote(
                                        woId: woIdString!,
                                        itemId: item.id,
                                        status: statusUpdate,
                                        mirroredNote: note) { result in
                                            self.handleStatusUpdateResult(result, item: item, newStatus: newStatus)
                                        }
                                }
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
                        
                        self.itemTimelineCard(for: item)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// ───── Helper Functions ─────
}

extension WorkOrderDetailView {
    private func handleStatusUpdateResult(_ result: Result<Void, Error>, item: WO_Item, newStatus: String) {
        switch result {
        case .success:
            #if DEBUG
            print("✅ Status updated for \(item.type) to '\(newStatus)'")
            #endif
            
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
