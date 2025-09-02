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

/*  ────────────────────────────────────────────────────────────────────────────
    WARNING — LOCKED VIEW (GUARDRAIL)
    GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT

    This view’s layout, UI, and behavior are CRITICAL to the workflow and tests.
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
        
        // Listen for work order updates from the database
        NotificationCenter.default.publisher(for: .WorkOrderSaved)
            .sink { [weak self] notification in
                guard let self = self,
                      let woNumber = notification.userInfo?["WO_Number"] as? String,
                      woNumber == self.workOrder.WO_Number else { return }
                
                print("🔄 WorkOrderDetailViewModel: Received notification for WO \(woNumber)")
                print("  - Current local status: \(self.workOrder.items.first?.statusHistory.last?.status ?? "none")")
                print("  - Notification userInfo: \(notification.userInfo ?? [:])")
                
                // Update the work order from the database
                Task { @MainActor in
                    await self.refreshWorkOrder()
                    // Force UI refresh after work order update
                    self.objectWillChange.send()
                }
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
        
        print("🔄 STATUS UPDATE: Starting status update for item \(itemIndex)")
        print("  - Current status: \(workOrder.items[itemIndex].statusHistory.last?.status ?? "none")")
        print("  - New status: \(status)")
        print("  - Work Order: \(workOrder.WO_Number)")
        
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
            
            print("✅ STATUS UPDATE: Local work order updated")
            print("  - New status history count: \(workOrder.items[itemIndex].statusHistory.count)")
            print("  - Latest status: \(workOrder.items[itemIndex].statusHistory.last?.status ?? "none")")
            
            // Save to Firebase using the specific update method
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let mirroredNote = WO_Note(
                    user: "Tech",
                    text: "Status changed to: \(status)",
                    timestamp: Date()
                )
                
                print("💾 STATUS UPDATE: Saving to Firebase...")
                workOrdersDB.updateItemStatusAndNote(
                    woId: workOrder.id ?? "",
                    itemId: workOrder.items[itemIndex].id,
                    status: newStatus,
                    mirroredNote: mirroredNote
                ) { result in
                    switch result {
                    case .success:
                        print("✅ STATUS UPDATE: Firebase save successful")
                        continuation.resume()
                    case .failure(let error):
                        print("❌ STATUS UPDATE: Firebase save failed: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            print("✅ STATUS UPDATE: Status update completed successfully")
            print("  - Final local status: \(workOrder.items[itemIndex].statusHistory.last?.status ?? "none")")
            
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
        
        // Ensure we have valid note text
        let finalNoteText = noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
            (imageURLs.isEmpty ? "Note added" : "Image added") : noteText
        
        do {
            let newNote = WO_Note(
                user: "Tech",
                text: finalNoteText,
                timestamp: Date(),
                imageURLs: imageURLs
            )
            
            print("📝 NOTE: Creating note with \(imageURLs.count) images")
            
            // Add note to the item
            workOrder.items[itemIndex].notes.append(newNote)
            
            workOrder.lastModified = Date()
            workOrder.lastModifiedBy = "Tech"
            
            // Save to Firebase using addItemNote method
            let workOrderId = workOrder.id ?? ""
            print("🔍 DEBUG: Adding note - workOrder.id: '\(workOrder.id ?? "nil")'")
            print("🔍 DEBUG: Adding note - workOrderId: '\(workOrderId)'")
            print("🔍 DEBUG: Adding note - workOrder.WO_Number: '\(workOrder.WO_Number)'")
            guard !workOrderId.isEmpty else {
                setError("Work order ID is missing")
                return
            }
            
            print("💾 SAVING: Note for WO \(workOrderId)")
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                workOrdersDB.addItemNote(
                    woId: workOrderId,
                    itemId: workOrder.items[itemIndex].id,
                    note: newNote
                ) { result in
                    switch result {
                    case .success:
                        print("✅ NOTE: Saved successfully")
                        
                        // After successfully saving the note, also add images to the item's main collection
                        if !imageURLs.isEmpty {
                            self.workOrdersDB.appendItemImagesFromNote(
                                woId: workOrderId,
                                itemId: self.workOrder.items[itemIndex].id,
                                imageURLs: imageURLs,
                                uploadedBy: "Tech"
                            ) { imageResult in
                                switch imageResult {
                                case .success:
                                    print("📸 IMAGES: Added \(imageURLs.count) images to item collection")
                                    // Both note and images are now saved, resume continuation
                                    continuation.resume()
                                case .failure(let error):
                                    print("⚠️ IMAGES: Failed to add to item collection: \(error)")
                                    // Don't fail the note save if image persistence fails
                                    continuation.resume()
                                }
                            }
                        } else {
                            // No images to add, resume continuation
                            continuation.resume()
                        }
                    case .failure(let error):
                        print("❌ NOTE: Failed to save: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            
        } catch {
            print("❌ NOTE: Error adding note: \(error.localizedDescription)")
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
        
        print("🔄 WorkOrderDetailViewModel: Starting refresh for \(workOrder.WO_Number)")
        
        do {
            let updatedWorkOrder = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorkOrder, Error>) in
                workOrdersDB.fetchWorkOrder(woId: workOrder.id ?? "") { result in
                    switch result {
                    case .success(let wo):
                        continuation.resume(returning: wo)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            await MainActor.run {
                let oldImageCount = self.workOrder.items.first?.imageUrls.count ?? 0
                let newImageCount = updatedWorkOrder.items.first?.imageUrls.count ?? 0
                
                // Debug status before refresh
                let oldStatus = self.workOrder.items.first?.statusHistory.last?.status ?? "none"
                let newStatus = updatedWorkOrder.items.first?.statusHistory.last?.status ?? "none"
                
                print("🔄 WorkOrderDetailViewModel: About to refresh work order \(workOrder.WO_Number)")
                print("  - Old status: \(oldStatus)")
                print("  - New status: \(newStatus)")
                print("  - Old image count: \(oldImageCount)")
                print("  - New image count: \(newImageCount)")
                print("  - Items updated: \(updatedWorkOrder.items.count)")
                
                self.workOrder = updatedWorkOrder
                
                print("🔄 WorkOrderDetailViewModel: Refresh completed")
                print("  - Final status: \(self.workOrder.items.first?.statusHistory.last?.status ?? "none")")
            }
        } catch {
            print("❌ WorkOrderDetailViewModel: Failed to refresh work order: \(error)")
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
        switch status.lowercased() {
        case "checked in":
            return UIConstants.StatusColors.checkedIn
        case "disassembly":
            return UIConstants.StatusColors.disassembly
        case "in progress":
            return UIConstants.StatusColors.inProgress
        case "test failed":
            return UIConstants.StatusColors.testFailed
        case "complete", "completed":
            return UIConstants.StatusColors.completed
        case "closed":
            return UIConstants.StatusColors.closed
        default:
            return UIConstants.StatusColors.fallback
        }
    }
    
    func getStatusDisplayName(_ status: String) -> String {
        switch status.lowercased() {
        case "checked in":
            return "Checked In"
        case "disassembly":
            return "Disassembly"
        case "in progress":
            return "In Progress"
        case "test failed":
            return "Test Failed"
        case "complete", "completed":
            return "Complete"
        case "closed":
            return "Closed"
        default:
            return status
        }
    }
}

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
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header Section
                headerSection
                
                // Work Order Items Section
                itemsSection()
            }
        }
        .padding(.horizontal, 12)
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
            
            // Temporary debug button for investigating missing data
            ToolbarItem(placement: .topBarLeading) {
                Button("Debug WO") {
                    print("🔍 DEBUG: Investigating work order \(viewModel.workOrder.WO_Number)")
                    print("  - ID: \(viewModel.workOrder.id ?? "nil")")
                    print("  - Items count: \(viewModel.workOrder.items.count)")
                    for (i, item) in viewModel.workOrder.items.enumerated() {
                        print("    Item \(i): type='\(item.type)', id=\(item.id)")
                        print("      - statusHistory count: \(item.statusHistory.count)")
                        print("      - notes count: \(item.notes.count)")
                        print("      - imageUrls count: \(item.imageUrls.count)")
                        print("      - reasonsForService: \(item.reasonsForService)")
                    }
                    
                    // Try to fetch fresh data from Firestore
                    if let woId = viewModel.workOrder.id, !woId.isEmpty {
                        print("🔄 Attempting to fetch fresh data from Firestore...")
                        
                        // First, let's see the raw Firestore data
                        let docRef = Firestore.firestore().collection("workOrders").document(woId)
                        docRef.getDocument { snapshot, error in
                            if let error = error {
                                print("❌ Failed to fetch raw data: \(error)")
                                return
                            }
                            
                            guard let snapshot = snapshot, snapshot.exists else {
                                print("❌ Work order not found in Firestore")
                                return
                            }
                            
                            print("🔍 RAW FIRESTORE DATA:")
                            print("  - Document ID: \(woId)")
                            print("  - All fields: \(snapshot.data()?.keys.sorted() ?? [])")
                            
                            if let itemsData = snapshot.data()?["items"] as? [[String: Any]] {
                                print("  - Items array count: \(itemsData.count)")
                                for (i, itemData) in itemsData.enumerated() {
                                    print("    Item \(i) raw data:")
                                    print("      - All keys: \(itemData.keys.sorted())")
                                    print("      - type: \(itemData["type"] ?? "nil")")
                                    print("      - id: \(itemData["id"] ?? "nil")")
                                    print("      - statusHistory: \(itemData["statusHistory"] ?? "nil")")
                                    print("      - notes: \(itemData["notes"] ?? "nil")")
                                    print("      - imageUrls: \(itemData["imageUrls"] ?? "nil")")
                                    print("      - reasonsForService: \(itemData["reasonsForService"] ?? "nil")")
                                }
                            } else {
                                print("  - Items field is not an array or missing")
                            }
                            
                            // Now try the normal fetch
                            WorkOrdersDatabase.shared.fetchWorkOrder(woId: woId) { result in
                                switch result {
                                case .success(let freshWorkOrder):
                                    print("✅ Fresh data fetched successfully")
                                    print("  - WO Number: \(freshWorkOrder.WO_Number)")
                                    print("  - Items count: \(freshWorkOrder.items.count)")
                                    for (i, item) in freshWorkOrder.items.enumerated() {
                                        print("    Item \(i): type='\(item.type)', id=\(item.id)")
                                    }
                                case .failure(let error):
                                    print("❌ Failed to fetch fresh data: \(error)")
                                }
                            }
                        }
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
        .fullScreenCover(isPresented: $showImageViewer) {
            if let url = selectedImageURL {
                FullScreenImageViewer(imageURL: url, isPresented: $showImageViewer)
            }
        }
        .onChange(of: showImageViewer) { _, isShowing in
            if !isShowing {
                selectedImageURL = nil
            }
        }
        .onAppear {
            print("🔍 DETAIL: WO \(viewModel.workOrder.WO_Number) has \(viewModel.workOrder.items.count) items")
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
                    print("📝 NOTE: Opening AddNoteSheet for WO \(viewModel.workOrder.WO_Number)")
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
                        // First dismiss the sheet, then show the image viewer
                        showAllThumbs = false
                        selectedImageURL = url
                        // Small delay to ensure sheet dismissal completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showImageViewer = true
                        }
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showImageViewer)
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
                        Text(viewModel.customerPhone.formattedPhoneNumber)
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
                .padding(.horizontal, 0)
            
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
            
            // Main content area with flexible layout (containerRelativeFrame 45/55)
            HStack(alignment: .top, spacing: 16) {

                // ── Images section (40% of card width)
                if !item.imageUrls.isEmpty || !item.thumbUrls.isEmpty {
                    WorkOrderItemImagesView(
                        item: item,
                        selectedImageURL: $selectedImageURL,
                        showImageViewer: $showImageViewer,
                        onShowAllThumbs: {
                            viewModel.selectedItemIndex = itemIndex
                            showAllThumbs = true
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear {
                        #if DEBUG
                        print("🔍 WO DETAILS: Item \(itemIndex) - \(item.type)")
                        print("  - imageUrls.count: \(item.imageUrls.count)")
                        print("  - thumbUrls.count: \(item.thumbUrls.count)")
                        if !item.imageUrls.isEmpty {
                            print("  - First imageUrl: \(item.imageUrls[0])")
                        }
                        if !item.thumbUrls.isEmpty {
                            print("  - First thumbUrl: \(item.thumbUrls[0])")
                        }
                        #endif
                    }
                } else {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("No Images")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                        .onAppear {
                            #if DEBUG
                            print("⚠️ WO DETAILS: No images to display for item \(itemIndex) - \(item.type)")
                            print("  - imageUrls.count: \(item.imageUrls.count)")
                            print("  - thumbUrls.count: \(item.thumbUrls.count)")
                            #endif
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
                                                                case .empty: 
                                                                    ProgressView()
                                                                        .frame(width: 72, height: 72)
                                                                case .success(let img):
                                                                    img.resizable().scaledToFill()
                                                                case .failure: 
                                                                    Color.gray
                                                                        .frame(width: 72, height: 72)
                                                                @unknown default: 
                                                                    Color.gray
                                                                        .frame(width: 72, height: 72)
                                                                }
                                                            }
                                                            .frame(width: 72, height: 72)
                                                            .clipped()
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
                    .onAppear {
                        // Force refresh when this view appears to ensure images are loaded
                        viewModel.objectWillChange.send()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
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
        "Complete",
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
                            // If no note text but there are images, add a default note
                            let finalNoteText = noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                "Image added" : noteText
                            uploadImagesAndAddNote(noteText: finalNoteText, images: selectedImages)
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
        
        print("📸 UPLOAD: Starting upload for \(images.count) images")
        
        // Check if we have valid IDs
        guard !woId.isEmpty && woId != "placeholder" else {
            print("❌ UPLOAD: Invalid work order ID: '\(woId)'")
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
            
            print("📸 UPLOAD: Image \(index) -> \(imageRef.fullPath)")
            
            // Convert image to data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                print("❌ UPLOAD: Failed to convert image \(index) to JPEG")
                group.leave()
                continue
            }
            
            // Upload to Firebase Storage
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            imageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    print("❌ UPLOAD: Image \(index) failed: \(error.localizedDescription)")
                    group.leave()
                    return
                }
                
                print("✅ UPLOAD: Image \(index) uploaded successfully")
                
                // Get download URL
                imageRef.downloadURL { url, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ UPLOAD: Failed to get download URL for image \(index): \(error.localizedDescription)")
                        return
                    }
                    
                    if let downloadURL = url {
                        print("✅ UPLOAD: Got download URL for image \(index)")
                        uploadedURLs.append(downloadURL.absoluteString)
                    } else {
                        print("❌ UPLOAD: Download URL is nil for image \(index)")
                    }
                }
            }
        }
        
        // When all uploads are complete, add the note
        group.notify(queue: .main) {
            self.isUploading = false
            print("📸 UPLOAD: Completed \(uploadedURLs.count) images")
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
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(imageURLs, id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            Button {
                                onThumbTapped(url)
                            } label: {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 150, height: 150)
                                    case .success(let img):
                                        img.resizable()
                                            .scaledToFit()
                                            .frame(width: 150, height: 150)
                                            .clipped()
                                    case .failure:
                                        Color.gray
                                            .frame(width: 150, height: 150)
                                    @unknown default:
                                        Color.gray
                                            .frame(width: 150, height: 150)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
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
