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
    
    var currentStatus: WO_Status {
        workOrder.statusHistory.last ?? WO_Status(status: "Checked In", user: "System", timestamp: workOrder.timestamp)
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
            
            // Save to Firebase
            try await withCheckedThrowingContinuation { continuation in
                workOrdersDB.updateWorkOrder(workOrder) { result in
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
        
        guard !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setError("Note text cannot be empty")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newNote = WO_Note(
                user: "Tech",
                text: noteText,
                timestamp: Date(),
                imageURLs: imageURLs
            )
            
            // Add note to the item
            workOrder.items[itemIndex].notes.append(newNote)
            
            // Add images to item if provided
            if !imageURLs.isEmpty {
                workOrder.items[itemIndex].imageUrls.append(contentsOf: imageURLs)
            }
            
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "Tech"
            
            // Save to Firebase
            try await withCheckedThrowingContinuation { continuation in
                workOrdersDB.updateWorkOrder(workOrder) { result in
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
            
            // Save to Firebase
            try await withCheckedThrowingContinuation { continuation in
                workOrdersDB.updateWorkOrder(workOrder) { result in
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
        
        do {
            if let refreshedWorkOrder = try await withCheckedThrowingContinuation({ continuation in
                workOrdersDB.getWorkOrder(by: workOrder.id ?? "") { result in
                    switch result {
                    case .success(let wo):
                        continuation.resume(returning: wo)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }) {
                workOrder = refreshedWorkOrder
            } else {
                setError("Work order not found")
            }
        } catch {
            setError("Failed to refresh work order: \(error.localizedDescription)")
        }
        
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
struct WorkOrderDetailView_Refactored: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: WorkOrderDetailViewModel
    
    // MARK: - UI State (View-specific only)
    @State private var showDeleteConfirm = false
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL? = nil
    @State private var showingPhoneActions = false
    
    // MARK: - Dependencies
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    // MARK: - Initialization
    init(
        workOrder: WorkOrder,
        onDelete: ((WorkOrder) -> Void)? = nil,
        onAddItemNote: ((WO_Item, WO_Note) -> Void)? = nil,
        onUpdateItemStatus: ((WO_Item, WO_Status, WO_Note) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: WorkOrderDetailViewModel(workOrder: workOrder))
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Section
                headerSection
                
                // Work Order Items Section
                itemsSection()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .onAppear {
            setupDebugLogging()
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
                StatusPickerSheet(
                    currentStatus: viewModel.workOrder.items[selectedIndex].statusHistory.last?.status ?? "Checked In",
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
                AddNoteSheet(
                    item: viewModel.workOrder.items[selectedIndex],
                    onNoteAdded: { noteText, imageURLs in
                        Task {
                            await viewModel.addNote(noteText, imageURLs: imageURLs, to: selectedIndex)
                        }
                        viewModel.showAddNoteSheet = false
                    },
                    isPresented: $viewModel.showAddNoteSheet
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
                // TODO: Implement delete functionality
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
                    Text(viewModel.customerName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
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
            Text("WO Items")
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
                    
                    if let tagId = item.tagId, !tagId.isEmpty {
                        Text("Tag: \(tagId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status badge (clickable)
                Button {
                    viewModel.selectedItemIndex = itemIndex
                    viewModel.showStatusPickerSheet = true
                } label: {
                    Text(item.statusHistory.last?.status ?? "Checked In")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(viewModel.getStatusColor(item.statusHistory.last?.status ?? "Checked In").opacity(0.2))
                        .foregroundColor(viewModel.getStatusColor(item.statusHistory.last?.status ?? "Checked In"))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // Images section
            if !item.imageUrls.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Images")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(item.imageUrls.enumerated()), id: \.offset) { index, urlString in
                                if let url = URL(string: urlString) {
                                    Button {
                                        selectedImageURL = url
                                        showImageViewer = true
                                    } label: {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .frame(width: 80, height: 80)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            case .failure:
                                                Color.gray
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            
            // Reasons for Service section
            if !item.reasonsForService.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reasons for Service")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(item.reasonsForService, id: \.self) { reason in
                            HStack {
                                Button {
                                    Task {
                                        await viewModel.toggleReasonCompletion(reason, for: itemIndex)
                                    }
                                } label: {
                                    Image(systemName: viewModel.isReasonCompleted(reason, for: item) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(viewModel.isReasonCompleted(reason, for: item) ? .green : .primary)
                                }
                                .buttonStyle(.plain)
                                
                                Text(reason)
                                    .font(.subheadline)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            
            // Notes & Status section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Notes & Status")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        viewModel.selectedItemIndex = itemIndex
                        viewModel.showAddNoteSheet = true
                    } label: {
                        Label("Add Note/Image", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                
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
                                Text(note.text)
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
                                                        selectedImageURL = url
                                                        showImageViewer = true
                                                    } label: {
                                                        AsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .empty:
                                                                ProgressView()
                                                                    .frame(width: 72, height: 72)
                                                            case .success(let img):
                                                                img.resizable().scaledToFill()
                                                                    .frame(width: 72, height: 72)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                            case .failure:
                                                                Color.gray.frame(width: 72, height: 72)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                            }
                                                        }
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
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Helper Methods
    
    private func setupDebugLogging() {
        #if DEBUG
        print("🔍 DETAIL: WO \(viewModel.workOrder.WO_Number) has \(viewModel.workOrder.items.count) items")
        #endif
    }
}

// MARK: - Preview
#Preview {
    WorkOrderDetailView_Refactored(
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
