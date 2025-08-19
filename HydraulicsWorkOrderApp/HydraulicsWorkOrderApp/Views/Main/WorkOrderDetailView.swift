//  WorkOrderDetailView.swift
//  HydraulicsWorkOrderApp
//  Created by Bec Archer on 8/8/25.

import SwiftUI
import Foundation

struct WorkOrderDetailView: View {
    let workOrder: WorkOrder
    var onDelete: ((WorkOrder) -> Void)? = nil
    var onAddItemNote: ((WO_Item, WO_Note) -> Void)? = nil
    var onUpdateItemStatus: ((WO_Item, WO_Status, WO_Note) -> Void)? = nil
    
    @State private var woLocal: WorkOrder
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
        _woLocal = State(initialValue: workOrder)
    }
    
    // ───── MAIN BODY ─────
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // ───── Header Section ─────
                headerSection()
                
                // ───── Work Order Items Section ─────
                itemsSection()
                
                // ───── Global Notes Timeline View ─────
                notesSection()
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
            if let url = selectedImageURL {
                FullScreenImageViewer(imageURL: url, isPresented: $showImageViewer)
            }
        }

    } // END body
    
    // ───── Header Section Extracted ─────
    @ViewBuilder
    private func headerSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("WO #\(woLocal.WO_Number)")
                    .font(.largeTitle.bold())
                StatusBadge(status: woLocal.status)
            }
            
            Text(woLocal.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                    Button {
                        let digitsOnlyPhone = woLocal.customerPhone.filter(\.isNumber)
                        if let telURL = URL(string: "tel://\(digitsOnlyPhone)") {
                            UIApplication.shared.open(telURL)
                        }
                    } label: {
                        Text(woLocal.customerPhone)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color(hex: "#FFC500"))
                    .contextMenu {
                        Button("Text") {
                            let digitsOnlyPhone = woLocal.customerPhone.filter(\.isNumber)
                            if let smsURL = URL(string: "sms:\(digitsOnlyPhone)") {
                                UIApplication.shared.open(smsURL)
                            }
                        }
                    }
                }
                .accessibilityLabel("Call or text customer")
                
                if woLocal.flagged {
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
            
            ForEach(woLocal.items) { item in
                HStack {
                    ItemCard(
                        item: item,
                        onImageTap: { url in
                            selectedImageURL = url
                            showImageViewer = true
                        },
                        onAddNote: { item, note in
                            if let idx = woLocal.items.firstIndex(where: { $0.id == item.id }) {
                                woLocal.items[idx].notes.append(note)
                                woLocal.lastModified = Date()
                                woLocal.lastModifiedBy = note.user

                                WorkOrdersDatabase.shared.addItemNote(
                                    woId: woLocal.id ?? "",
                                    itemId: item.id,
                                    note: note
                                ) { result in
                                    switch result {
                                    case .success:
                                        print("✅ Note saved for \(item.type)")
                                    case .failure(let err):
                                        print("❌ Failed to save note: \(err.localizedDescription)")
                                    }
                                }
                            }
                            onAddItemNote?(item, note)
                        },
                        onChangeStatus: { item, newStatus in
                            let author = appState.currentUserName.isEmpty ? "Tech" : appState.currentUserName
                            let ts = Date()
                            let statusEntry = WO_Status(status: newStatus, user: author, timestamp: ts, notes: nil)
                            let systemNote  = WO_Note(user: author, text: "Status changed to \(newStatus)", timestamp: ts)

                            if let idx = woLocal.items.firstIndex(where: { $0.id == item.id }) {
                                woLocal.items[idx].statusHistory.append(statusEntry)
                                woLocal.items[idx].notes.append(systemNote)
                                woLocal.lastModified = ts
                                woLocal.lastModifiedBy = author

                                WorkOrdersDatabase.shared.updateItemStatusAndNote(
                                    woId: woLocal.id ?? "",
                                    itemId: item.id,
                                    status: statusEntry,
                                    mirroredNote: systemNote
                                ) { result in
                                    switch result {
                                    case .success:
                                        print("✅ WO_Status saved for \(newStatus)")
                                    case .failure(let err):
                                        print("❌ Failed to save WO_Status: \(err.localizedDescription)")
                                    }
                                }
                            }

                            onUpdateItemStatus?(item, statusEntry, systemNote)
                        }
                    )
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6)) // 🩶 Light gray background for card
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.gray.opacity(0.1))
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                .padding(.horizontal, 0) // Optional: match container padding
            }

        }
    }
    
    // ───── Global Notes Timeline Section ─────
    @ViewBuilder
    private func notesSection() -> some View {
        let allNotes = woLocal.items.flatMap { $0.notes }
        if !allNotes.isEmpty {
            NotesTimelineView(notes: allNotes)
                .padding(.top, 12)
        }
    }
    // END

    
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
            )
        )
        .environmentObject(AppState.shared)
    }
}
