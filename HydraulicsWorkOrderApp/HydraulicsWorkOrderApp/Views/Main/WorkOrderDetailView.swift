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
import UIKit
import Combine

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
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) // taps stay inside
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}
// MARK: - ViewModel (Temporarily included for testing)
@MainActor
class WorkOrderDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var workOrder: WorkOrder
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showAddNoteSheet = false
    @Published var showStatusPickerSheet = false
    @Published var selectedItemIndex: Int?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let workOrdersDB = WorkOrdersDatabase.shared
    // TODO: Re-enable after fixing module resolution
    // private let imageService = ImageManagementService.shared
    
    // MARK: - Computed Properties
    var customerName: String {
        workOrder.customerName
    }
    
    var customerCompany: String? {
        workOrder.customerCompany
    }
    
    var customerEmail: String? {
        workOrder.customerEmail
    }
    
    var customerPhone: String {
        workOrder.customerPhone
    }
    
    var isTaxExempt: Bool {
        workOrder.customerTaxExempt
    }
    
    var currentStatus: String {
        workOrder.status
    }
    
    // MARK: - Initialization
    init(workOrder: WorkOrder) {
        self.workOrder = workOrder
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor work order changes for validation
        $workOrder
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Update the status of a specific item
    func updateItemStatus(_ status: String, for itemIndex: Int, note: String? = nil) async {
        guard itemIndex >= 0 && itemIndex < workOrder.items.count else {
            setError("Invalid item index")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create new status entry
            let newStatus = WO_Status(
                status: status,
                user: "Tech",
                timestamp: Date(),
                notes: note
            )
            
            // Update the work order
            workOrder.items[itemIndex].statusHistory.append(newStatus)
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "Tech"
            
            // Save to Firebase using the specific update method
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let mirroredNote = WO_Note(
                    user: "Tech",
                    text: "Status changed to: \(status)",
                    timestamp: Date(),
                    imageURLs: []
                )
                workOrdersDB.updateItemStatusAndNote(
                    woId: workOrder.id ?? "",
                    itemId: workOrder.items[itemIndex].id,
                    status: newStatus,
                    mirroredNote: mirroredNote
                ) { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
        } catch {
            setError("Failed to update status: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Add a note to a specific item
    func addNote(_ noteText: String, imageURLs: [String] = [], to itemIndex: Int) async {
        guard itemIndex >= 0 && itemIndex < workOrder.items.count else {
            setError("Invalid item index")
            return
        }
        
        // Validation is handled in AddNoteSheet, so we don't need to validate here
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newNote = WO_Note(
                user: "Tech",
                text: noteText,
                timestamp: Date(),
                imageURLs: imageURLs
            )
            
            print("📝 WorkOrderDetailView: Creating note with \(imageURLs.count) images")
            for (i, url) in imageURLs.enumerated() {
                print("  Image URL \(i): \(url)")
            }
            
            // Add note to the item
            workOrder.items[itemIndex].notes.append(newNote)
            
            // Add images to item if provided
            if !imageURLs.isEmpty {
                workOrder.items[itemIndex].imageUrls.append(contentsOf: imageURLs)
            }
            
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "Tech"
            
            // Save to Firebase using addItemNote method
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                workOrdersDB.addItemNote(
                    woId: workOrder.id ?? "",
                    itemId: workOrder.items[itemIndex].id,
                    note: newNote
                ) { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
        } catch {
            setError("Failed to add note: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Toggle completion of a reason for service
    func toggleReasonCompletion(_ reason: String, for itemIndex: Int) async {
        guard itemIndex >= 0 && itemIndex < workOrder.items.count else {
            setError("Invalid item index")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var item = workOrder.items[itemIndex]
            
            if item.completedReasons.contains(reason) {
                item.completedReasons.removeAll { $0 == reason }
            } else {
                item.completedReasons.append(reason)
            }
            
            workOrder.items[itemIndex] = item
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "Tech"
            
            // Save to Firebase using updateCompletedReasons method
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let note = WO_Note(
                    user: "Tech",
                    text: "Updated reasons for service completion",
                    timestamp: Date(),
                    imageURLs: []
                )
                workOrdersDB.updateCompletedReasons(
                    woId: workOrder.id ?? "",
                    itemId: workOrder.items[itemIndex].id,
                    completedReasons: item.completedReasons,
                    note: note
                ) { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
        } catch {
            setError("Failed to update reason completion: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Refresh work order data from Firebase
    func refreshWorkOrder() async {
        isLoading = true
        errorMessage = nil
        
        // TODO: Implement refresh functionality when getWorkOrder method is available
        // For now, just return success without refreshing
        print("⚠️ Refresh functionality not yet implemented")
        
        isLoading = false
    }
    
    /// Get the display text for "Other" reason notes
    func getOtherReasonDisplayText(for item: WO_Item) -> String? {
        guard let reasonNotes = item.reasonNotes, !reasonNotes.isEmpty else { return nil }
        return "✅ Other: \(reasonNotes)"
    }
    
    /// Check if a reason is completed for an item
    func isReasonCompleted(_ reason: String, for item: WO_Item) -> Bool {
        item.completedReasons.contains(reason)
    }
    
    // MARK: - Private Methods
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Helper Extensions
extension WorkOrderDetailViewModel {
    func getStatusColor(_ status: String) -> Color {
        switch status {
        case "Checked In":
            return .blue
        case "Disassembly":
            return .teal
        case "In Progress":
            return .yellow
        case "Test Failed":
            return .red
        case "Complete":
            return .green
        case "Closed":
            return .gray
        default:
            return .primary
        }
    }
    
    func getStatusDisplayName(_ status: String) -> String {
        switch status {
        case "Checked In":
            return "Checked In"
        case "Disassembly":
            return "Disassembly"
        case "In Progress":
            return "In Progress"
        case "Test Failed":
            return "Test Failed"
        case "Complete":
            return "Complete"
        case "Closed":
            return "Closed"
        default:
            return status
        }
    }
}

// MARK: - View
struct WorkOrderDetailView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: WorkOrderDetailViewModel
    
    // MARK: - UI State (View-specific only)
    @State private var showDeleteConfirm = false
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL? = nil
    @State private var showingPhoneActions = false
    @State private var showAllThumbs = false
    
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
        List {
            Section {
                // Header Section
                headerSection
                    .listRowSeparator(.hidden)
                
                // Work Order Items Section
                itemsSection()
            }
            .listSectionSeparator(.hidden)
        }
        .listSectionSeparator(.hidden)
        .listRowSeparator(.hidden)
        .listStyle(PlainListStyle())
        .environment(\.defaultMinListRowHeight, 0)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
                }
            }
        }
        .alert("Delete this Work Order?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete?(viewModel.workOrder)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the WorkOrder from Active. Managers/Admins can still access it in Deleted WorkOrders.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
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
        .onAppear {
            #if DEBUG
            print("🔍 WorkOrderDetailView: WorkOrder \(viewModel.workOrder.WO_Number) has \(viewModel.workOrder.items.count) items")
            #endif
        }
        .sheet(isPresented: $showingPhoneActions) {
            PhoneActionSheet(
                customerName: viewModel.customerName,
                phoneNumber: viewModel.customerPhone,
                isPresented: $showingPhoneActions
            )
        }
        .sheet(isPresented: $viewModel.showStatusPickerSheet) {
            if let selectedIndex = viewModel.selectedItemIndex {
                let currentStatus = viewModel.workOrder.items[selectedIndex].statusHistory.last?.status ?? "Checked In"
                StatusPickerSheet(
                    currentStatus: currentStatus,
                    onStatusSelected: { newStatus in
                        Task {
                            await viewModel.updateItemStatus(newStatus, for: selectedIndex)
                        }
                        viewModel.showStatusPickerSheet = false
                    },
                    isPresented: $viewModel.showStatusPickerSheet
                )
            }
        }
        .sheet(isPresented: $viewModel.showAddNoteSheet) {
            if let selectedIndex = viewModel.selectedItemIndex {
                let item = viewModel.workOrder.items[selectedIndex]
                let workOrderId = viewModel.workOrder.id ?? ""
                
                AddNoteSheet(
                    item: item,
                    workOrderId: workOrderId,
                    onNoteAdded: { noteText, imageURLs in
                        Task {
                            await viewModel.addNote(noteText, imageURLs: imageURLs, to: selectedIndex)
                        }
                        viewModel.showAddNoteSheet = false
                    },
                    isPresented: $viewModel.showAddNoteSheet
                )
                .onAppear {
                    print("🔍 WorkOrderDetailView: Opening AddNoteSheet")
                    print("  Work Order ID: '\(workOrderId)'")
                    print("  Work Order Number: \(viewModel.workOrder.WO_Number)")
                    print("  Item ID: \(item.id)")
                }
            }
        }
        .sheet(isPresented: $showAllThumbs) {
            if let selectedIndex = viewModel.selectedItemIndex {
                let allThumbs = Array(viewModel.workOrder.items[selectedIndex].imageUrls.dropFirst())
                AllThumbnailsSheet(
                    imageURLs: allThumbs,
                    isPresented: $showAllThumbs,
                    onThumbTapped: { url in
                        selectedImageURL = url
                        showImageViewer = true
                    }
                )
            }
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Left Column - Work Order Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Work Order #\(viewModel.workOrder.WO_Number)")
                    .font(.largeTitle.bold())
            
                    Text(viewModel.workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Right Column - Customer Info
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text(viewModel.customerName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if canDelete {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                    } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                        }
                    }
                    
                    if let company = viewModel.customerCompany, !company.isEmpty {
                        Text(company)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                        Text(viewModel.customerPhone)
                            .underline()
                            .foregroundColor(Color(hex: "#FFC500"))
                            .onLongPressGesture {
                                showingPhoneActions = true
                            }
                    }
                    .accessibilityLabel("Call or text customer")
                    
                    if viewModel.isTaxExempt {
                        Text("*Customer is tax exempt")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Flagged indicator (if needed)
            if viewModel.workOrder.flagged {
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
    
    // MARK: - Work Order Items Section
    @ViewBuilder
    private func itemsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Work Order Items")
                .font(.title3.weight(.semibold))
            
            if viewModel.workOrder.items.isEmpty {
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
                ForEach(Array(viewModel.workOrder.items.enumerated()), id: \.element.id) { idx, item in
                    combinedItemCard(item: item, itemIndex: idx)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
    }
    
    // MARK: - Combined Item Card
    @ViewBuilder
    private func combinedItemCard(item: WO_Item, itemIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Item header with status badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.type)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        if let tagId = item.tagId, !tagId.isEmpty {
                            Text("Tag: \(tagId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let woItemId = item.woItemId {
                            Text("ID: \(woItemId)")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Reasons for Service section
                if !item.reasonsForService.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Reasons for Service")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(item.reasonsForService, id: \.self) { reason in
                                HStack {
                                    Text(reason)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    Button {
                                        Task {
                                            await viewModel.toggleReasonCompletion(reason, for: itemIndex)
                                        }
                                    } label: {
                                        Image(systemName: viewModel.isReasonCompleted(reason, for: item) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(viewModel.isReasonCompleted(reason, for: item) ? .green : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Status badge (clickable)
                Button {
                    viewModel.selectedItemIndex = itemIndex
                    viewModel.showStatusPickerSheet = true
                } label: {
                    Text(item.statusHistory.last?.status ?? "Checked In")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(viewModel.getStatusColor(item.statusHistory.last?.status ?? "Checked In").opacity(0.2))
                        .foregroundColor(viewModel.getStatusColor(item.statusHistory.last?.status ?? "Checked In"))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            // Main content area with flexible layout (containerRelativeFrame 45/55)
            HStack(alignment: .top, spacing: 16) {

                // ── Images section (40% of card width)
                if !item.imageUrls.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        // ── Primary Image (larger, takes up more space)
                        if let firstUrl = URL(string: item.imageUrls[0]) {
                            Button {
                                selectedImageURL = firstUrl
                                showImageViewer = true
                            } label: {
                                AsyncImage(url: firstUrl) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipped()
                                    case .failure:
                                        Color.gray
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                    @unknown default:
                                        Color.gray
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        // ── Thumbnail Grid (2x2 grid below primary image)
                        if item.imageUrls.count > 1 {
                            let additionalImages = Array(item.imageUrls.dropFirst())
                            let displayImages = Array(additionalImages.prefix(4)) // Show up to 4 thumbnails
                            let extraCount = max(0, additionalImages.count - displayImages.count)

                            GeometryReader { g in
                                let spacing: CGFloat = 6
                                let thumbSize = (g.size.width - spacing) / 2

                                VStack(spacing: spacing) {
                                    // First row of thumbnails
                                    HStack(spacing: spacing) {
                                        ForEach(0..<min(2, displayImages.count), id: \.self) { idx in
                                            if let url = URL(string: displayImages[idx]) {
                                                Button {
                                                    if extraCount > 0 && idx == displayImages.count - 1 {
                                                        viewModel.selectedItemIndex = itemIndex
                                                        showAllThumbs = true
                                                    } else {
                                                        selectedImageURL = url
                                                        showImageViewer = true
                                                    }
                                                } label: {
                                                    ZStack {
                                                        AsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .empty:
                                                                ProgressView()
                                                                    .frame(width: thumbSize, height: thumbSize)
                                                            case .success(let img):
                                                                img.resizable()
                                                                    .scaledToFill()
                                                                    .frame(width: thumbSize, height: thumbSize)
                                                                    .clipped()
                                                            case .failure:
                                                                Color.gray
                                                                    .frame(width: thumbSize, height: thumbSize)
                                                            @unknown default:
                                                                Color.gray
                                                                    .frame(width: thumbSize, height: thumbSize)
                                                            }
                                                        }
                                                        if extraCount > 0 && idx == displayImages.count - 1 {
                                                            Rectangle()
                                                                .fill(Color.black.opacity(0.35))
                                                                .frame(width: thumbSize, height: thumbSize)
                                                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                                            Text("+\(extraCount)")
                                                                .font(.caption.weight(.semibold))
                                                                .foregroundColor(.white)
                                                        }
                                                    }
                                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        // Fill empty spaces to maintain grid
                                        if displayImages.count < 2 {
                                            ForEach(0..<(2 - displayImages.count), id: \.self) { _ in
                                                Color.clear
                                                    .frame(width: thumbSize, height: thumbSize)
                                            }
                                        }
                                    }
                                    
                                    // Second row of thumbnails (if we have more than 2 images)
                                    if displayImages.count > 2 {
                                        HStack(spacing: spacing) {
                                            ForEach(2..<min(4, displayImages.count), id: \.self) { idx in
                                                if let url = URL(string: displayImages[idx]) {
                                                    Button {
                                                        if extraCount > 0 && idx == displayImages.count - 1 {
                                                            viewModel.selectedItemIndex = itemIndex
                                                            showAllThumbs = true
                                                        } else {
                                                            selectedImageURL = url
                                                            showImageViewer = true
                                                        }
                                                    } label: {
                                                        ZStack {
                                                            AsyncImage(url: url) { phase in
                                                                switch phase {
                                                                case .empty:
                                                                    ProgressView()
                                                                        .frame(width: thumbSize, height: thumbSize)
                                                                case .success(let img):
                                                                    img.resizable()
                                                                        .scaledToFill()
                                                                        .frame(width: thumbSize, height: thumbSize)
                                                                        .clipped()
                                                                case .failure:
                                                                    Color.gray
                                                                        .frame(width: thumbSize, height: thumbSize)
                                                                @unknown default:
                                                                    Color.gray
                                                                        .frame(width: thumbSize, height: thumbSize)
                                                                }
                                                            }
                                                            if extraCount > 0 && idx == displayImages.count - 1 {
                                                                Rectangle()
                                                                    .fill(Color.black.opacity(0.35))
                                                                    .frame(width: thumbSize, height: thumbSize)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                                                Text("+\(extraCount)")
                                                                    .font(.caption.weight(.semibold))
                                                                    .foregroundColor(.white)
                                                            }
                                                        }
                                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            // Fill empty spaces to maintain grid
                                            if displayImages.count < 4 {
                                                ForEach(0..<(4 - displayImages.count), id: \.self) { _ in
                                                    Color.clear
                                                        .frame(width: thumbSize, height: thumbSize)
                                                }
                                            }
                                        }
                                    }
                                }
                                .frame(height: displayImages.count > 2 ? thumbSize * 2 + spacing : thumbSize)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .ifAvailableiOS17 {
                        $0.containerRelativeFrame([.horizontal], alignment: .leading) { available, _ in
                            (available - 16) * 0.40   // 40% of the HStack width minus spacing
                        }
                    }
                }

                // ── Notes & Status section (60%)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notes & Status")
                        .font(.headline)

                    // Status history
                    if !item.statusHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(item.statusHistory.enumerated()), id: \.offset) { _, status in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(viewModel.getStatusColor(status.status))
                                        .padding(.top, 6)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(status.status)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(viewModel.getStatusColor(status.status))
                                        Text("\(status.user) • \(status.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Notes
                    if !item.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(item.notes.enumerated()), id: \.offset) { _, note in
                                VStack(alignment: .leading, spacing: 4) {
                                    // Special formatting for "Updated reasons for service completion" notes
                                    if note.text == "Updated reasons for service completion" {
                                        let completedReasons = item.completedReasons
                                        if !completedReasons.isEmpty {
                                            Text("✅ \(completedReasons.joined(separator: ", ")) • by \(note.user)")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text("\(note.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("✅ [No reasons completed] • by \(note.user)")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text("\(note.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text(note.text)
                                            .font(.subheadline)
                                        Text("\(note.user) • \(note.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if !note.imageURLs.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(Array(note.imageURLs.enumerated()), id: \.offset) { _, urlStr in
                                                    if let url = URL(string: urlStr) {
                                                        Button {
                                                            selectedImageURL = url
                                                            showImageViewer = true
                                                        } label: {
                                                            AsyncImage(url: url) { phase in
                                                                switch phase {
                                                                case .empty: ProgressView()
                                                                case .success(let img):
                                                                    img.resizable().scaledToFill()
                                                                case .failure: Color.gray
                                                                @unknown default: Color.gray
                                                                }
                                                            }
                                                            .frame(width: 72, height: 72)
                                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Add Note/Image button at the bottom
                    Button {
                        viewModel.selectedItemIndex = itemIndex
                        viewModel.showAddNoteSheet = true
                    } label: {
                        Label("Add Note/Image", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }
                .padding(.horizontal, 8)
                                    .ifAvailableiOS17 {
                        $0.containerRelativeFrame([.horizontal], alignment: .trailing) { available, _ in
                            (available - 16) * 0.60   // 60% of the HStack width minus spacing
                        }
                    }
            }
            .padding(.horizontal, 20)
            .frame(height: 400) // keep your fixed overall height
            .clipped() // ensure internal content cannot spill horizontally/vertically
            // END
        }
        .card()
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - StatusPickerSheet
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
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Text("Select Status")
                .font(.title2)
                .fontWeight(.semibold)
            
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
        .padding(.bottom, 20)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - AddNoteSheet
struct AddNoteSheet: View {
    let item: WO_Item
    let workOrderId: String
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
        
        // Use the actual work order ID passed from parent
        let woId = workOrderId
        let itemId = item.id.uuidString
        
        print("📸 AddNoteSheet: Starting upload for \(images.count) images")
        print("  Work Order ID: \(woId)")
        print("  Item ID: \(itemId)")
        
        // Check if we have valid IDs
        guard !woId.isEmpty && woId != "placeholder" else {
            print("❌ AddNoteSheet: Invalid work order ID: '\(woId)'")
            self.isUploading = false
            self.onNoteAdded(noteText, [])
            self.isPresented = false
            return
        }
        
        // Upload images to Firebase Storage
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        var uploadedURLs: [String] = []
        let group = DispatchGroup()
        
        for (index, image) in images.enumerated() {
            group.enter()
            
            // Create a unique filename with more uniqueness
            let timestamp = Int(Date().timeIntervalSince1970)
            let randomSuffix = Int.random(in: 1000...9999)
            let filename = "\(timestamp)_\(randomSuffix)_\(index).jpg"
            let imageRef = storageRef.child("intake/\(woId)/\(itemId)/\(filename)")
            
            print("📸 AddNoteSheet: Uploading image \(index) to path: \(imageRef.fullPath)")
            
            // Convert image to data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                print("❌ AddNoteSheet: Failed to convert image \(index) to JPEG data")
                group.leave()
                continue
            }
            
            // Upload to Firebase Storage
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            imageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    print("❌ AddNoteSheet: Image upload failed for image \(index): \(error.localizedDescription)")
                    group.leave()
                    return
                }
                
                print("✅ AddNoteSheet: Image \(index) uploaded successfully")
                
                // Get download URL
                imageRef.downloadURL { url, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ AddNoteSheet: Failed to get download URL for image \(index): \(error.localizedDescription)")
                        return
                    }
                    
                    if let downloadURL = url {
                        print("✅ AddNoteSheet: Got download URL for image \(index): \(downloadURL.absoluteString)")
                        uploadedURLs.append(downloadURL.absoluteString)
                    } else {
                        print("❌ AddNoteSheet: Download URL is nil for image \(index)")
                    }
                }
            }
        }
        
        // When all uploads are complete, add the note
        group.notify(queue: .main) {
            self.isUploading = false
            print("📸 AddNoteSheet: Uploaded \(uploadedURLs.count) images")
            for (i, url) in uploadedURLs.enumerated() {
                print("  Image \(i): \(url)")
            }
            self.onNoteAdded(noteText, uploadedURLs)
            self.isPresented = false
        }
    }
}

// MARK: - ImagePicker
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

// MARK: - Preview
#Preview {
    WorkOrderDetailView(
        workOrder: WorkOrder(
            id: "preview-work-order-id",
            createdBy: "Preview User",
            customerId: "preview-customer-id",
            customerName: "Bec Archer",
            customerCompany: "Hydraulic Solutions Inc.",
            customerEmail: "bec@hydraulics.com",
            customerTaxExempt: false,
            customerPhone: "239-246-7352",
            WO_Type: "Cylinder",
            imageURL: nil,
            imageURLs: nil,
            timestamp: Date(),
            status: "Disassembly",
            WO_Number: "250827-785",
            flagged: false,
            tagId: "TAG-001",
            estimatedCost: "1250.00",
            finalCost: nil,
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            lastModified: Date(),
            lastModifiedBy: "Preview User",
            tagBypassReason: nil,
            isDeleted: false,
            notes: [],
            items: [
                WO_Item(
                    id: UUID(),
                    woItemId: "250827-785-WOI-001",
                    tagId: "TAG-001",
                    imageUrls: [
                        "https://picsum.photos/400/400?random=1",
                        "https://picsum.photos/200/200?random=2",
                        "https://picsum.photos/200/200?random=3",
                        "https://picsum.photos/200/200?random=4"
                    ],
                    thumbUrls: [],
                    type: "Cylinder",
                    dropdowns: [:],
                    dropdownSchemaVersion: 1,
                    reasonsForService: ["Replace Seals", "Inspect Piston", "Check for Wear"],
                    reasonNotes: nil,
                    completedReasons: [],
                    statusHistory: [
                        WO_Status(status: "Checked In", user: "Tech", timestamp: Date().addingTimeInterval(-86400)),
                        WO_Status(status: "Disassembly", user: "Tech", timestamp: Date())
                    ],
                    testResult: nil,
                    partsUsed: nil,
                    hoursWorked: nil,
                    cost: nil,
                    assignedTo: "",
                    isFlagged: false,
                    tagReplacementHistory: nil
                ),
                WO_Item(
                    id: UUID(),
                    woItemId: "250827-785-WOI-002",
                    tagId: "TAG-002",
                    imageUrls: [
                        "https://picsum.photos/400/400?random=5",
                        "https://picsum.photos/200/200?random=6"
                    ],
                    thumbUrls: [],
                    type: "Pump",
                    dropdowns: [:],
                    dropdownSchemaVersion: 1,
                    reasonsForService: ["Replace Bearings", "Check Pressure"],
                    reasonNotes: nil,
                    completedReasons: [],
                    statusHistory: [
                        WO_Status(status: "Checked In", user: "Tech", timestamp: Date().addingTimeInterval(-7200))
                    ],
                    testResult: nil,
                    partsUsed: nil,
                    hoursWorked: nil,
                    cost: nil,
                    assignedTo: "",
                    isFlagged: false,
                    tagReplacementHistory: nil
                )
            ]
        ),
        onDelete: nil,
        onAddItemNote: nil,
        onUpdateItemStatus: nil
    )
    .environmentObject(AppState.shared)
}



// MARK: - AllThumbnailsSheet
struct AllThumbnailsSheet: View {
    let imageURLs: [String]
    @Binding var isPresented: Bool
    let onThumbTapped: (URL) -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(imageURLs, id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            Button {
                                onThumbTapped(url)
                            } label: {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                    case .success(let img):
                                        img.resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipped()
                                    case .failure:
                                        Color.gray
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                    @unknown default:
                                        Color.gray
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12)
            }
            .navigationTitle("All Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
