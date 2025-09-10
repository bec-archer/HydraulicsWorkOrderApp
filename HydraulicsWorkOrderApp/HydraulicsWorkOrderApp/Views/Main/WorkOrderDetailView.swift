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
                    
                    // Customer Information Card
                    customerInfoCard
                    
                    // Work Order Header Card
                    workOrderHeaderCard
                    
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Work Order Items")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(viewModel.workOrder.items.count) items")
                        .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.workOrder.items.enumerated()), id: \.element.id) { index, item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.type)
                                .font(.headline)
                            Spacer()
                            Text(item.assetTagId ?? "No Tag")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !item.imageUrls.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(item.imageUrls, id: \.self) { imageURL in
                                        AsyncImage(url: URL(string: imageURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 80)
                                                .clipped()
                                                .cornerRadius(8)
                                                .onTapGesture {
                                                    print("🔍 DEBUG: WorkOrderDetailView tap detected on image: \(imageURL)")
                                                    if let url = URL(string: imageURL) {
                                                        selectedImageURL = url
                                                        showImageViewer = true
                                                        print("🔍 DEBUG: WorkOrderDetailView tap - full-screen viewer should now be presented")
                                                    }
                                                }
                                                .simultaneousGesture(
                                                    LongPressGesture(minimumDuration: 0.5)
                                                        .onEnded { _ in
                                                            print("🔍 DEBUG: WorkOrderDetailView long-press detected on image: \(imageURL)")
                                                            if let url = URL(string: imageURL) {
                                                                selectedImageURL = url
                                                                showImageViewer = true
                                                                print("🔍 DEBUG: WorkOrderDetailView long-press - full-screen viewer should now be presented")
                                                            }
                                                        }
                                                )
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 80, height: 80)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        HStack {
                            Button("Update Status") {
                                viewModel.selectedItemIndex = index
                                viewModel.showStatusPickerSheet = true
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Add Note") {
                                viewModel.selectedItemIndex = index
                                viewModel.showAddNoteSheet = true
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .card()
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
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Phone Actions")
                        .font(.headline)
            
            Text(phoneNumber)
                .font(.title2)
                .fontWeight(.medium)
            
            VStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: "tel:\(phoneNumber)") {
                        UIApplication.shared.open(url)
                    }
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