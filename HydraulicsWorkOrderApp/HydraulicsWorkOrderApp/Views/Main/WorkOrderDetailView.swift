//
//  WorkOrderDetailView_Refactored.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderDetailView_Refactored.swift
// Refactored version using WorkOrderDetailViewModel for better separation of concerns
// ─────────────────────────────────────────────────────────────


import SwiftUI
import Foundation
import FirebaseStorage
import FirebaseFirestore
import UIKit
import Combine


// MARK: - TagReplacementView Component
struct TagReplacementView: View {
    let workOrderItem: WO_Item
    let onTagReplaced: (TagReplacement) -> Void
    
    @State private var newTagId = ""
    @State private var reason = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Current Tag") {
                    HStack {
                        Text("Current Tag ID:")
                        Spacer()
                        Text(workOrderItem.assetTagId ?? "None")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("New Tag Information") {
                    TextField("New Tag ID", text: $newTagId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Reason for replacement (optional)", text: $reason, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Replace Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Replace") {
                        let replacement = TagReplacement(
                            oldTagId: workOrderItem.assetTagId ?? "",
                            newTagId: newTagId,
                            replacedBy: "current_user", // TODO: Get from auth
                            reason: reason.isEmpty ? nil : reason
                        )
                        onTagReplaced(replacement)
                        dismiss()
                    }
                    .disabled(newTagId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/*  ────────────────────────────────────────────────────────────────────────────
    WARNING — LOCKED VIEW (GUARDRAIL)
    GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT

    This view's layout, UI, and behavior are CRITICAL to the workflow and tests.
    DO NOT change, refactor, or alter layout/styling/functionality in this file.

    Allowed edits ONLY:
      • Comments and documentation
      • Preview sample data (non-shipping)
      • Bugfixes that are 100% no-visual-change (must be verifiable in Preview)

    Any change beyond the above requires explicit approval from Bec.
    Rationale: This screen matches shop SOPs and downstream QA expectations.
    ──────────────────────────────────────────────────────────────────────────── */

extension View {
    /// Applies a transform only on iOS 17+, returns the original view otherwise.
    @ViewBuilder
    func ifAvailableiOS17<Content: View>(_ transform: (Self) -> Content) -> some View {
        if #available(iOS 17, *) {
            transform(self)
        } else {
            self
        }
    }
}
// END
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) // taps stay inside
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

// MARK: - ViewModel Integration
// Using dedicated WorkOrderDetailViewModel from Views/ViewModels/

// MARK: - View
// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.
struct WorkOrderDetailView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: WorkOrderDetailViewModel
    
    // MARK: - UI State (View-specific only)
    @State private var showDeleteConfirm = false
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL? = nil
    @State private var showingPhoneActions = false
    @State private var showAllThumbs = false
    @State private var showTagReplacement = false
    @State private var selectedItemForTagReplacement: WO_Item?
    
    // MARK: - Dependencies
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    // MARK: - Callbacks
    private let onDelete: ((WorkOrder) -> Void)?
    private let onAddItemNote: ((WO_Item, WO_Note) -> Void)?
    private let onUpdateItemStatus: ((WO_Item, WO_Status, WO_Note) -> Void)?
    
    // MARK: - Initialization
    init(
        workOrder: WorkOrder,
        onDelete: ((WorkOrder) -> Void)? = nil,
        onAddItemNote: ((WO_Item, WO_Note) -> Void)? = nil,
        onUpdateItemStatus: ((WO_Item, WO_Status, WO_Note) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: WorkOrderDetailViewModel(workOrder: workOrder))
        self.onDelete = onDelete
        self.onAddItemNote = onAddItemNote
        self.onUpdateItemStatus = onUpdateItemStatus
    }
    
    // MARK: - Computed Properties
    private var canDelete: Bool {
#if DEBUG
        return true
#else
        return appState.canDeleteWorkOrders()
#endif
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
                    
                    // New Work Order Header Banner
                    workOrderHeaderBanner
                    
                    // Items Section
                    itemsSection
                    
                    // Notes Timeline
                    notesTimelineSection
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
                    onDelete?(viewModel.workOrder)
                    dismiss()
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
        .sheet(isPresented: $viewModel.showStatusPickerSheet) {
                StatusPickerSheet(
                    currentStatus: viewModel.currentStatus,
                    onStatusSelected: { status in
                        Task {
                            await viewModel.updateItemStatus(status, for: viewModel.selectedItemIndex ?? 0)
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
        .fullScreenCover(isPresented: $showImageViewer) {
            if let imageURL = selectedImageURL {
                FullScreenImageViewer(imageURL: imageURL, isPresented: $showImageViewer)
                    .onAppear {
                        print("🔍 DEBUG: WorkOrderDetailView FullScreenCover presenting with URL: \(imageURL.absoluteString)")
                    }
            } else {
                Text("No image selected")
                    .foregroundColor(.white)
                    .background(Color.black)
                    .onAppear {
                        print("🔍 DEBUG: WorkOrderDetailView FullScreenCover triggered but no selectedImageURL")
                        print("🔍 DEBUG: showImageViewer: \(showImageViewer), selectedImageURL: \(selectedImageURL?.absoluteString ?? "nil")")
                    }
            }
        }
        .onChange(of: showImageViewer) { oldValue, newValue in
            print("🔍 DEBUG: WorkOrderDetailView showImageViewer changed from: \(oldValue) to: \(newValue)")
        }
        .onChange(of: selectedImageURL) { oldValue, newValue in
            print("🔍 DEBUG: WorkOrderDetailView selectedImageURL changed from: \(oldValue?.absoluteString ?? "nil") to: \(newValue?.absoluteString ?? "nil")")
        }
        .sheet(isPresented: $showingPhoneActions) {
            PhoneActionSheet(phoneNumber: viewModel.workOrder.customerPhone, customerName: viewModel.workOrder.customerName)
        }
    }
    
    // MARK: - Work Order Header Banner
    private var workOrderHeaderBanner: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // Left side: Work Order title and timestamp
                VStack(alignment: .leading, spacing: 0) {
                    Text("Work Order #\(viewModel.workOrder.workOrderNumber)")
                        .font(ThemeManager.shared.titleFont)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    
                    Text(viewModel.workOrder.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                    +
                    Text(" at ")
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                    +
                    Text(viewModel.workOrder.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                }
                
                Spacer()
                
                // Right side: Customer name and phone
                VStack(alignment: .trailing, spacing: 0) {
                    Text(viewModel.workOrder.customerName)
                        .font(.system(size: 20 * 0.8 * 1.5)) // 80% of title font size, then 50% larger
                        .fontWeight(.bold)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    
                    Button(action: {
                        showingPhoneActions = true
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 12 * 1.5)) // 50% larger than caption
                            Text(formatPhoneNumber(viewModel.workOrder.customerPhone))
                                .font(.system(size: 12 * 1.5)) // 50% larger than caption
                                .fontWeight(.bold)
                        }
                        .foregroundColor(ThemeManager.shared.linkColor)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(ThemeManager.shared.cardBackground)
        .cornerRadius(ThemeManager.shared.cardCornerRadius)
        .shadow(
            color: ThemeManager.shared.cardShadowColor.opacity(ThemeManager.shared.cardShadowOpacity),
            radius: 8,
            x: 0,
            y: 4
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Work Order \(viewModel.workOrder.workOrderNumber), created \(viewModel.workOrder.timestamp, style: .date), customer \(viewModel.workOrder.customerName)")
    }
    
    // MARK: - Customer Info Card
    private var customerInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Customer Information")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                    HStack {
                    Text("Name:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        if let emoji = viewModel.workOrder.customerEmojiTag, !emoji.isEmpty {
                            Text(emoji)
                                .font(.subheadline)
                        }
                        Text(viewModel.customerName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
                
                HStack {
                    Text("Phone:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    Button(viewModel.customerPhone) {
                                showingPhoneActions = true
                            }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    Spacer()
                    }
                    
                if let company = viewModel.customerCompany {
                    HStack {
                        Text("Company:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(company)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                }
            }
            
                if let email = viewModel.customerEmail {
                HStack {
                        Text("Email:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(email)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    Spacer()
                }
            }
            
            HStack {
                    Text("Tax Exempt:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.isTaxExempt ? "Yes" : "No")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(viewModel.isTaxExempt ? .green : .red)
                Spacer()
            }
        }
        }
        .card()
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
    
    // MARK: - Work Order Header Card
    private var workOrderHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Work Order Information")
                        .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                if viewModel.workOrder.flagged {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("WO Number:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.workOrder.workOrderNumber)
                        .font(.subheadline)
                        .fontWeight(.medium)
                Spacer()
                }
                
                HStack {
                    Text("Status:")
                            .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.currentStatus)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor(viewModel.currentStatus))
                    Spacer()
                }
                
                                HStack {
                    Text("Created:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.workOrder.timestamp, style: .date)
                        .font(.subheadline)
                                        .fontWeight(.medium)
                    Spacer()
                }
                
                HStack {
                    Text("Last Modified:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.workOrder.lastModified, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        }
        .card()
    }
    
    // MARK: - Items Section
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
                ForEach(Array(viewModel.workOrder.items.enumerated()), id: \.element.id) { index, item in
                    WOItemCard(
                        workOrder: viewModel.workOrder,
                        item: item,
                        itemIndex: index,
                        onImageTap: { imageURL in
                            if let url = URL(string: imageURL) {
                                selectedImageURL = url
                                showImageViewer = true
                            }
                        },
                        onReasonChecked: { reason in
                            Task {
                                await viewModel.addServicePerformedStatus(for: index, reason: reason)
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - WO Item Card Component
    private struct WOItemCard: View {
        let workOrder: WorkOrder
        let item: WO_Item
        let itemIndex: Int
        let onImageTap: (String) -> Void
        let onReasonChecked: (String) -> Void
        
        @State private var showImageViewer = false
        @State private var selectedImageURL: URL?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header row: Composite item number, Reasons checkboxes, StatusBadge
                HStack {
                    Text("\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
                        .font(.headline)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    
                    Spacer()
                    
                    // StatusBadge for individual item
                    StatusBadge(status: item.statusHistory.last?.status ?? "Checked In")
                }
                
                // Type line
                Text(item.type)
                    .font(.subheadline)
                    .foregroundColor(ThemeManager.shared.textSecondary)
                
                // Reasons for Service checkboxes
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(item.reasonsForService, id: \.self) { reason in
                        HStack {
                            Button(action: {
                                onReasonChecked(reason)
                            }) {
                                Image(systemName: isReasonPerformed(reason) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(isReasonPerformed(reason) ? ThemeManager.shared.linkColor : ThemeManager.shared.textSecondary)
                            }
                            .disabled(isReasonPerformed(reason))
                            
                            Text(reason)
                                .font(.subheadline)
                                .foregroundColor(ThemeManager.shared.textPrimary)
                            
                            Spacer()
                        }
                        
                        // Show reason notes if "Other" and has notes
                        if reason.lowercased().contains("other") && !(item.reasonNotes?.isEmpty ?? true) {
                            Text(item.reasonNotes ?? "")
                                .font(.caption)
                                .foregroundColor(ThemeManager.shared.textSecondary)
                                .padding(.leading, 24)
                        }
                    }
                }
                
                // Main body split: Left (images) + Right (notes & status)
                HStack(alignment: .top, spacing: 16) {
                    // Left: Primary image + 2x2 thumbnails
                    VStack(spacing: 8) {
                        // Primary 1:1 image
                        if let firstImageURL = item.imageUrls.first {
                            AsyncImage(url: URL(string: firstImageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipped()
                                    .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                                    .onTapGesture {
                                        onImageTap(firstImageURL)
                                    }
                            } placeholder: {
                                Rectangle()
                                    .fill(ThemeManager.shared.border.opacity(0.3))
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                            }
                        }
                        
                        // 2x2 thumbnail grid
                        if item.imageUrls.count > 1 {
                            LazyVGrid(columns: [
                                GridItem(.fixed(50), spacing: 4),
                                GridItem(.fixed(50), spacing: 4)
                            ], spacing: 4) {
                                ForEach(Array(item.imageUrls.dropFirst().prefix(3).enumerated()), id: \.offset) { thumbIndex, imageURL in
                                    AsyncImage(url: URL(string: imageURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipped()
                                            .cornerRadius(6)
                                            .onTapGesture {
                                                onImageTap(imageURL)
                                            }
                                    } placeholder: {
                                        Rectangle()
                                            .fill(ThemeManager.shared.border.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                            .cornerRadius(6)
                                    }
                                }
                                
                                // Show +Qty if more than 4 images total
                                if item.imageUrls.count > 4 {
                                    ZStack {
                                        Rectangle()
                                            .fill(ThemeManager.shared.border.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                            .cornerRadius(6)
                                        
                                        Text("+\(item.imageUrls.count - 4)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(ThemeManager.shared.textPrimary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 120)
                    
                    // Right: Notes & Status timeline
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes & Status")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ThemeManager.shared.textPrimary)
                        
                        // Item-specific notes and status history
                        LazyVStack(alignment: .leading, spacing: 4) {
                            // Show "Checked In" as default if no status history
                            if item.statusHistory.isEmpty {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Checked In")
                                            .font(.caption)
                                            .foregroundColor(ThemeManager.shared.textPrimary)
                                        
                                        HStack {
                                            Text("System")
                                                .font(.caption2)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                            
                                            Text("•")
                                                .font(.caption2)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                            
                                            Text("Initial Status")
                                                .font(.caption2)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            ForEach(item.statusHistory.sorted(by: { $0.timestamp < $1.timestamp }), id: \.timestamp) { status in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(status.status)
                                            .font(.caption)
                                            .foregroundColor(ThemeManager.shared.textPrimary)
                                        
                                        HStack {
                                            Text(status.user)
                                                .font(.caption2)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                            
                                            Text("•")
                                                .font(.caption2)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                            
                                            Text(status.timestamp, style: .time)
                                                .font(.caption2)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                        }
                                        
                                        if let notes = status.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.caption2)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                                .italic()
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            // Item-specific notes
                            ForEach(item.notes.sorted(by: { $0.timestamp < $1.timestamp }), id: \.timestamp) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(note.text)
                                            .font(.caption)
                                            .foregroundColor(ThemeManager.shared.textPrimary)
                                        
                                        HStack {
                                            Text(note.user)
                                                .font(.caption2)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                            
                                            Text("•")
                                                .font(.caption2)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                            
                                            Text(note.timestamp, style: .time)
                                                .font(.caption2)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                        }
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
        
        private func isReasonPerformed(_ reason: String) -> Bool {
            return item.statusHistory.contains { status in
                status.status == "Service Performed — \(reason)"
            }
        }
    }
    
    // MARK: - Notes Timeline Section
    private var notesTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes & Status History")
                        .font(.headline)
                                                .foregroundColor(.primary)
                Spacer()
            }
            
            NotesTimelineView(notes: viewModel.workOrder.notes)
        }
        .card()
    }
    
    // MARK: - Helper Methods
    
    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let digits = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Format with dashes based on length
        if digits.count == 10 {
            // Format as XXX-XXX-XXXX
            let areaCode = String(digits.prefix(3))
            let firstThree = String(digits.dropFirst(3).prefix(3))
            let lastFour = String(digits.suffix(4))
            return "\(areaCode)-\(firstThree)-\(lastFour)"
        } else if digits.count == 11 && digits.hasPrefix("1") {
            // Format as 1-XXX-XXX-XXXX
            let countryCode = String(digits.prefix(1))
            let areaCode = String(digits.dropFirst(1).prefix(3))
            let firstThree = String(digits.dropFirst(4).prefix(3))
            let lastFour = String(digits.suffix(4))
            return "\(countryCode)-\(areaCode)-\(firstThree)-\(lastFour)"
        } else {
            // Return original if not a standard format
            return phoneNumber
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "checked in":
            return .blue
        case "in progress":
            return .orange
        case "completed":
            return .green
        case "closed":
            return .gray
        default:
            return .primary
        }
    }
}

// MARK: - PhoneActionSheet
struct PhoneActionSheet: View {
    let phoneNumber: String
    let customerName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Contact \(customerName)")
                    .font(.headline)
                
                Text(phoneNumber)
                    .font(.title2)
                    .fontWeight(.medium)
            
                VStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "tel:\(phoneNumber)") {
                            UIApplication.shared.open(url)
                        }
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Call")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        if let url = URL(string: "sms:\(phoneNumber)") {
                            UIApplication.shared.open(url)
                        }
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Text")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = phoneNumber
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc.fill")
                            Text("Copy")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
            .navigationTitle("Phone Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.6, maxHeight: UIScreen.main.bounds.height * 0.6)
        .presentationDragIndicator(.visible)
    }
}

// MARK: - StatusPickerSheet
struct StatusPickerSheet: View {
    let currentStatus: String
    let onStatusSelected: (String) -> Void
    
    private let statuses = ["Checked In", "In Progress", "Completed", "Closed"]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(statuses, id: \.self) { status in
                    Button(action: {
                        onStatusSelected(status)
                    }) {
                        HStack {
                            Text(status)
                                .foregroundColor(.primary)
                            Spacer()
                            if status == currentStatus {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        // Dismiss sheet
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - AddNoteSheet
struct AddNoteSheet: View {
    let workOrder: WorkOrder
    let onAddNote: (WO_Note) -> Void
    
    @State private var noteText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Enter note...", text: $noteText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                            Image(uiImage: image)
                                                .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        Button(action: {
                                                selectedImages.remove(at: index)
                                        }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .background(Color.white)
                                                    .clipShape(Circle())
                                            }
                                        .padding(4),
                                        alignment: .topTrailing
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Button("Add Images") {
                    showingImagePicker = true
                    }
                    .buttonStyle(.bordered)
                    
                Spacer()
                }
                .padding()
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let note = WO_Note(
                            id: UUID(),
                            workOrderId: workOrder.id,
                            user: "Tech", // TODO: Get from auth
                            text: noteText,
                            timestamp: Date()
                        )
                        onAddNote(note)
                        dismiss()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImages: $selectedImages)
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
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
                parent.selectedImages.append(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
    WorkOrderDetailView(
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
            )
        )
    }
    .environmentObject(AppState.shared)
}