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
    @StateObject private var workOrdersDB = WorkOrdersDatabase.shared
    
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
        .onAppear {
            print("🔍 DEBUG: WorkOrderDetailView onAppear - refreshing work order data from Firebase")
            Task {
                await refreshWorkOrderFromFirebase()
            }
        }
    }
    
    // MARK: - Data Refresh
    private func refreshWorkOrderFromFirebase() async {
        print("🔍 DEBUG: refreshWorkOrderFromFirebase called for WO: \(viewModel.workOrder.workOrderNumber)")
        
        // Use the completion-based method to get fresh work order data
        workOrdersDB.fetchWorkOrder(woId: viewModel.workOrder.id) { result in
            Task { @MainActor in
                switch result {
                case .success(let freshWorkOrder):
                    print("🔍 DEBUG: Got fresh work order from Firebase with \(freshWorkOrder.items.count) items")
                    viewModel.updateWorkOrder(freshWorkOrder)
                    print("🔍 DEBUG: Updated viewModel with fresh work order data")
                case .failure(let error):
                    print("❌ DEBUG: Failed to refresh work order from Firebase: \(error)")
                }
            }
        }
    }
    
    // MARK: - Work Order Header Banner
    /*  ────────────────────────────────────────────────────────────────────────────
        GUARDRAIL: DO NOT MODIFY HEADER LAYOUT
        The header layout, spacing, font sizes, and positioning are finalized and approved.
        DO NOT change, refactor, or alter any aspect of this header without explicit approval.
        Current state: Compact design with proper spacing, tappable phone with action sheet.
        ──────────────────────────────────────────────────────────────────────────── */
    private var workOrderHeaderBanner: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // Left side: Work Order title and timestamp
                VStack(alignment: .leading, spacing: 0) {
                    Text("Work Order #\(viewModel.workOrder.workOrderNumber)")
                        .font(ThemeManager.shared.titleFont)
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
                        .foregroundColor(viewModel.getStatusColor(viewModel.currentStatus))
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
                        onReasonToggled: { reason in
                            print("🔍 DEBUG: Checkbox toggled for reason: '\(reason)' on item index: \(index)")
                            Task { @MainActor in
                                print("🔍 DEBUG: About to call toggleServicePerformedStatus")
                                await viewModel.toggleServicePerformedStatus(for: index, reason: reason)
                                print("🔍 DEBUG: toggleServicePerformedStatus completed")
                            }
                        },
                        onStatusChanged: { newStatus in
                            print("🔍 DEBUG: Status changed to: '\(newStatus)' for item index: \(index)")
                            Task { @MainActor in
                                print("🔍 DEBUG: About to call updateItemStatus")
                                await viewModel.updateItemStatus(newStatus, for: index)
                                print("🔍 DEBUG: updateItemStatus completed")
                            }
                        },
                        onNotesAdded: { noteText, images in
                            print("🔍 DEBUG: Notes added: '\(noteText)' with \(images.count) images for item index: \(index)")
                            Task { @MainActor in
                                print("🔍 DEBUG: About to call addItemNoteWithImages")
                                await viewModel.addItemNoteWithImages(noteText, images: images, to: index)
                                print("🔍 DEBUG: addItemNoteWithImages completed")
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
                // Header row: Composite item number • Reasons (checkboxes) • StatusBadge
                HStack(alignment: .top, spacing: 12) {
                    // Left: Composite WO_Number-ItemIndex (e.g., 250826-001-003)
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
                            StatusBadge(status: item.statusHistory.last?.status ?? "Checked In")
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
                        
                        VStack(spacing: 8) {
                                // PRIMARY 1:1 image
                                if let firstImageURL = item.imageUrls.first {
                                    AsyncImage(url: URL(string: firstImageURL)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill() // crop, do not stretch
                                            .frame(width: primarySize, height: primarySize)
                                            .clipped()
                                            .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                                            .onTapGesture { onImageTap(firstImageURL) }
                                    } placeholder: {
                                        Rectangle()
                                            .fill(ThemeManager.shared.border.opacity(0.3))
                                            .frame(width: primarySize, height: primarySize)
                                            .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                                    }
                                } else {
                                    // No images: placeholder primary
                                    Rectangle()
                                        .fill(ThemeManager.shared.border.opacity(0.2))
                                        .frame(width: primarySize, height: primarySize)
                                        .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.system(size: primarySize * 0.12, weight: .regular))
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                        )
                                }
                                
                                // 2×2 thumbnails directly beneath primary (images 2,3,4, +Qty)
                                if item.imageUrls.count > 1 {
                                    let extras = Array(item.imageUrls.dropFirst())
                                    LazyVGrid(
                                        columns: [
                                            GridItem(.fixed(thumbSize), spacing: gridSpacing),
                                            GridItem(.fixed(thumbSize), spacing: gridSpacing)
                                        ],
                                        spacing: gridSpacing
                                    ) {
                                        ForEach(Array(extras.prefix(3).enumerated()), id: \.offset) { _, imageURL in
                                            AsyncImage(url: URL(string: imageURL)) { img in
                                                img.resizable()
                                                    .scaledToFill()
                                                    .frame(width: thumbSize, height: thumbSize)
                                                    .clipped()
                                                    .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                                    .onTapGesture { onImageTap(imageURL) }
                                            } placeholder: {
                                                Rectangle()
                                                    .fill(ThemeManager.shared.border.opacity(0.3))
                                                    .frame(width: thumbSize, height: thumbSize)
                                                    .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                            }
                                        }
                                        
                                        // +Qty tile if there are 6 or more total images
                                        if item.imageUrls.count >= 6 {
                                            Button(action: {
                                                // Show gallery for all images
                                                showGallery = true
                                            }) {
                                                ZStack {
                                                    // Show the 5th image (index 4) as background
                                                    AsyncImage(url: URL(string: item.imageUrls[4])) { image in
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: thumbSize, height: thumbSize)
                                                            .clipped()
                                                            .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                                    } placeholder: {
                                                        Rectangle()
                                                            .fill(ThemeManager.shared.border.opacity(0.3))
                                                            .frame(width: thumbSize, height: thumbSize)
                                                            .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                                    }
                                                    
                                                    // Dark overlay
                                                    Rectangle()
                                                        .fill(Color.black.opacity(0.6))
                                                        .frame(width: thumbSize, height: thumbSize)
                                                        .cornerRadius(ThemeManager.shared.cardCornerRadius - 6)
                                                    
                                                    // +Qty text
                                                    Text("+\(item.imageUrls.count - 4)")
                                                        .font(.headline)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .frame(width: primarySize, alignment: .leading) // grid width matches primary
                                }
                        }
                    }
                    
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
                            
                            ForEach(item.statusHistory.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { status in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(status.status)
                                            .font(.system(size: 12 * 1.2))
                                            .fontWeight(.bold)
                                            .foregroundColor(getStatusColor(status.status))
                                        
                                        HStack {
                                            Text(status.user)
                                                .font(.system(size: 10 * 1.2))
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                            
                                            Text("•")
                                                .font(.system(size: 10 * 1.2))
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                            
                                            Text(status.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                                .font(.system(size: 10 * 1.2))
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            // Item-specific notes
                            ForEach(item.notes.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Show text if available
                                        if !note.text.isEmpty {
                                            Text(note.text)
                                                .font(.system(size: 12 * 1.2))
                                                .foregroundColor(ThemeManager.shared.textPrimary)
                                        }
                                        
                                        // Show image thumbnails if available
                                        if !note.imageUrls.isEmpty {
                                            let _ = print("🔍 DEBUG: Note has \(note.imageUrls.count) image URLs: \(note.imageUrls)")
                                            HStack(spacing: 4) {
                                                ForEach(note.imageUrls.prefix(3), id: \.self) { imageUrl in
                                                    Button(action: {
                                                        // Convert thumbnail URL back to full image URL for full screen viewing
                                                        let fullImageUrl = convertThumbnailUrlToImageUrl(imageUrl)
                                                        print("🔍 DEBUG: Note thumbnail tapped - Original: \(imageUrl)")
                                                        print("🔍 DEBUG: Note thumbnail tapped - Converted: \(fullImageUrl)")
                                                        selectedImageURL = URL(string: fullImageUrl)
                                                        print("🔍 DEBUG: Note thumbnail tapped - selectedImageURL set to: \(selectedImageURL?.absoluteString ?? "nil")")
                                                        showImageViewer = true
                                                        print("🔍 DEBUG: Note thumbnail tapped - showImageViewer set to: \(showImageViewer)")
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
                                        
                                        HStack {
                                            Text(note.user)
                                                .font(.system(size: 10 * 1.2))
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                            
                                            Text("•")
                                                .font(.system(size: 10 * 1.2))
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                            
                                            Text(note.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                                .font(.system(size: 10 * 1.2))
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
            .sheet(isPresented: $showGallery) {
                ImageGalleryView(images: item.imageUrls, title: "\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
            }
            .sheet(isPresented: $showStatusSelection) {
                StatusSelectionView(
                    currentStatus: item.statusHistory.last?.status ?? "Checked In",
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
            .onChange(of: selectedImageURL) { oldValue, newValue in
                print("🔍 DEBUG: WOItemCard selectedImageURL changed from: \(oldValue?.absoluteString ?? "nil") to: \(newValue?.absoluteString ?? "nil")")
            }
            .onChange(of: showImageViewer) { oldValue, newValue in
                print("🔍 DEBUG: WOItemCard showImageViewer changed from: \(oldValue) to: \(newValue)")
                if newValue {
                    print("🔍 DEBUG: WOItemCard showImageViewer is true, selectedImageURL: \(selectedImageURL?.absoluteString ?? "nil")")
                }
            }
            .fullScreenCover(isPresented: $showImageViewer) {
                if let imageURL = selectedImageURL {
                    FullScreenImageViewer(imageURL: imageURL, isPresented: $showImageViewer)
                        .onAppear {
                            print("🔍 DEBUG: FullScreenCover presenting with URL: \(imageURL.absoluteString)")
                        }
                } else {
                    Text("No image selected")
                        .onAppear {
                            print("🔍 DEBUG: FullScreenCover triggered but selectedImageURL is nil")
                        }
                }
            }
        }
        
        func isReasonPerformed(_ reason: String) -> Bool {
            let expectedStatus = "Service Performed — \(reason)"
            return item.statusHistory.contains { status in
                status.status == expectedStatus
            }
        }

        func summaryLineForItem(_ item: WO_Item) -> String {
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
        
        func convertThumbnailUrlToImageUrl(_ thumbnailUrl: String) -> String {
            // For now, just return the thumbnail URL directly since the full-size image might not exist
            // The thumbnail is already a reasonable size for full-screen viewing
            print("🔍 DEBUG: Using thumbnail URL directly instead of converting to full image URL")
            return thumbnailUrl
        }
    }
    
    
    // MARK: - Helper Methods
    
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

// MARK: - ImageGalleryView
struct ImageGalleryView: View {
    let images: [String]
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var showFullScreen = false
    @State private var selectedImageURL: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: 8)
                ], spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, imageURL in
                        Button(action: {
                            selectedImageURL = URL(string: imageURL)
                            showFullScreen = true
                        }) {
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                            } placeholder: {
                                Rectangle()
                                    .fill(ThemeManager.shared.border.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                                    .overlay(ProgressView())
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let imageURL = selectedImageURL {
                FullScreenImageViewer(imageURL: imageURL, isPresented: $showFullScreen)
            }
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

// MARK: - StatusSelectionView
struct StatusSelectionView: View {
    let currentStatus: String
    let onStatusSelected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Status options with colors
    private let statusOptions = [
        ("Checked In", Color.blue),
        ("Disassembly", Color.purple),
        ("In Progress", Color.yellow),
        ("Test Failed", Color.red),
        ("Complete", Color.green),
        ("Closed", Color.gray)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Change Status")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    
                    Text("Current: \(currentStatus)")
                        .font(.subheadline)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Status options
                VStack(spacing: 12) {
                    ForEach(statusOptions, id: \.0) { status, color in
                        Button(action: {
                            onStatusSelected(status)
                        }) {
                            HStack {
                                // Status color indicator
                                Circle()
                                    .fill(color)
                                    .frame(width: 12, height: 12)
                                
                                Text(status)
                                    .font(.body)
                                    .foregroundColor(ThemeManager.shared.textPrimary)
                                
                                Spacer()
                                
                                // Current status indicator
                                if status == currentStatus {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(ThemeManager.shared.linkColor)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ThemeManager.shared.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                status == currentStatus ? ThemeManager.shared.linkColor : ThemeManager.shared.border,
                                                lineWidth: status == currentStatus ? 2 : 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(ThemeManager.shared.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ThemeManager.shared.linkColor)
                }
            }
        }
    }
}

// MARK: - AddNotesView
struct AddNotesView: View {
    let workOrder: WorkOrder
    let item: WO_Item
    let itemIndex: Int
    let onNotesAdded: (String, [UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @State private var noteText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Add Notes")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    
                    Text("\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
                        .font(.subheadline)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Notes text field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                                .foregroundColor(ThemeManager.shared.textPrimary)
                            
                            TextEditor(text: $noteText)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(ThemeManager.shared.cardBackground)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(ThemeManager.shared.border, lineWidth: 1)
                                )
                        }
                        
                        // Images section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Images")
                                    .font(.headline)
                                    .foregroundColor(ThemeManager.shared.textPrimary)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingImagePicker = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                        Text("Add Photos")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(ThemeManager.shared.linkColor)
                                }
                            }
                            
                            if selectedImages.isEmpty {
                                Text("No images selected")
                                    .font(.subheadline)
                                    .foregroundColor(ThemeManager.shared.textSecondary)
                                    .italic()
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 80), spacing: 8)
                                ], spacing: 8) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 80)
                                                .clipped()
                                                .cornerRadius(8)
                                            
                                            Button(action: {
                                                selectedImages.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .background(Color.white)
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 8, y: -8)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(ThemeManager.shared.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ThemeManager.shared.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNotes()
                    }
                    .foregroundColor(ThemeManager.shared.linkColor)
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImages.isEmpty || isSaving)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImages: $selectedImages)
        }
    }
    
    private func saveNotes() {
        guard !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty else {
            return
        }
        
        isSaving = true
        onNotesAdded(noteText, selectedImages)
    }
}