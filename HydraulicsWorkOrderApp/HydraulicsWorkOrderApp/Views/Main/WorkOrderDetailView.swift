//
//  WorkOrderDetailView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//

// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderDetailView.swift
// Detail view for a selected WorkOrder
// + Toolbar Delete (role‑gated) with confirmation
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct WorkOrderDetailView: View {
    let workOrder: WorkOrder

    // 🔌 Parent provides deletion behavior (soft delete + sync)
    // Keep this optional so the view compiles even if caller hasn't wired it yet.
    var onDelete: ((WorkOrder) -> Void)? = nil
    // 🔌 Bubble up when a tech adds an item note; parent decides how to persist
    var onAddItemNote: ((WO_Item, WO_Note) -> Void)? = nil
    // 🔌 When a tech changes status; parent should persist statusHistory and append a system note
    var onUpdateItemStatus: ((WO_Item, WO_Status, WO_Note) -> Void)? = nil
    
    // Local working copy so UI updates immediately on add/update
    @State private var woLocal: WorkOrder

    // Custom init: seed woLocal from the passed-in WorkOrder
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


    // ───── Environment / State ─────
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var showDeleteConfirm = false

    // ───── Role Gate: who can delete? (DEV bypass) ─────
    // During development we always show Delete to test soft delete.
    // TODO: remove DEBUG bypass when role gates are enforced.
    private var canDelete: Bool {
        #if DEBUG
        return true
        #else
        return appState.canDeleteWorkOrders()
        #endif
    }

    var body: some View {
        // Use local state for rendering so mutations trigger a refresh
        let workOrder = woLocal

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ───── HEADER CARD (WO number, status, phone, flagged) ─────
                VStack(alignment: .leading, spacing: 12) {

                    // Title + Status
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("WO #\(workOrder.WO_Number)")
                            .font(.largeTitle.bold())

                        // Status badge
                        StatusBadge(status: workOrder.status)
                    }

                    // Created timestamp
                    Text(workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    // Phone (tappable) + Flagged chip
                    HStack(spacing: 12) {
                        // ───── Tappable Phone (call + context menu for text) ─────
                        HStack(spacing: 6) {
                            Image(systemName: "phone.fill")
                            Button {
                                let digits = workOrder.customerPhone.filter(\.isNumber)
                                if let telURL = URL(string: "tel://\(digits)") {
                                    UIApplication.shared.open(telURL)
                                }
                            } label: {
                                Text(workOrder.customerPhone)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(Color(hex: "#FFC500")) // Apple‑Notes yellow accent
                            .contextMenu {
                                Button("Text") {
                                    let digits = workOrder.customerPhone.filter(\.isNumber)
                                    if let smsURL = URL(string: "sms:\(digits)") {
                                        UIApplication.shared.open(smsURL)
                                    }
                                }
                            }
                        }
                        .accessibilityLabel("Call or text customer")
                        // END tappable phone

                        if workOrder.flagged {
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
                // END header card

                // ───── ITEMS LIST ─────
                VStack(alignment: .leading, spacing: 12) {
                    Text("WO Items")
                        .font(.title3.weight(.semibold))

                    ForEach(woLocal.items) { item in
                        ItemCard(
                            item: item,
                            onAddNote: { item, text in
                                let author = appState.currentUserName.isEmpty ? "Tech" : appState.currentUserName
                                let note = WO_Note(user: author, text: text, timestamp: Date())

                                // 1) Update local state so UI refreshes immediately
                                if let idx = woLocal.items.firstIndex(where: { $0.id == item.id }) {
                                    woLocal.items[idx].notes.append(note)
                                    woLocal.lastModified = Date()
                                    woLocal.lastModifiedBy = author
                                }

                                // 2) Bubble up so the caller can persist to Firestore/SQLite
                                onAddItemNote?(item, note)
                            },
                            onChangeStatus: { item, newStatus in
                                let author = appState.currentUserName.isEmpty ? "Tech" : appState.currentUserName
                                let ts = Date()
                                let statusEntry = WO_Status(status: newStatus, user: author, timestamp: ts, notes: nil)
                                let systemNote  = WO_Note(user: author, text: "Status changed to \(newStatus)", timestamp: ts)

                                // 1) Update local state for instant UI feedback
                                if let idx = woLocal.items.firstIndex(where: { $0.id == item.id }) {
                                    // Ensure statusHistory exists; default to empty if your model is older
                                    if woLocal.items[idx].statusHistory.isEmpty { /* no-op; property should exist */ }
                                    woLocal.items[idx].statusHistory.append(statusEntry)
                                    woLocal.items[idx].notes.append(systemNote)
                                    woLocal.lastModified = ts
                                    woLocal.lastModifiedBy = author
                                }

                                // 2) Bubble up for persistence
                                onUpdateItemStatus?(item, statusEntry, systemNote)
                            }
                        )
                    }


                }
                // END items list
                
                // ───── TIMELINE • TECH NOTES (WorkOrder-level) ─────
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timeline • Tech Notes")
                        .font(.title3.weight(.semibold))

                    if !workOrder.notes.isEmpty {
                        // Newest first for quick scanning
                        let ordered = workOrder.notes.sorted { $0.timestamp > $1.timestamp }

                        VStack(spacing: 10) {
                            ForEach(ordered) { note in
                                NoteRow(note: note)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.06))
                        )

                    } else {
                        // Fallback row if no notes were saved yet:
                        // Render "Checked In by <name> at <time>" using WorkOrder fields
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .imageScale(.small)
                                    .opacity(0.7)
                                Text((workOrder.createdBy.isEmpty ? "Tech" : workOrder.createdBy))
                                    .font(.footnote.weight(.semibold))
                                Text(workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                            }
                            Text("Checked In")
                                .font(.callout)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.06))
                        )
                    }
                }
                .padding(.top, 8)
                // END timeline


            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Work Order Details")
        .navigationBarTitleDisplayMode(.inline)

        // ───── Toolbar: Delete (role‑gated) ─────
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

        // ───── Confirm Delete Alert ─────
        .alert("Delete this Work Order?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete?(workOrder)   // Parent should soft‑delete + sync
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the WorkOrder from Active. Managers/Admins can still access it in Deleted WorkOrders.")
        }
        // END .body
    }

}
// ───── Item Card ─────
private struct ItemCard: View {
    let item: WO_Item

    // Parent-provided callbacks
    var onAddNote: ((WO_Item, String) -> Void)? = nil
    var onChangeStatus: ((WO_Item, String) -> Void)? = nil

    // Local composer state (per card)
    @State private var newNoteText: String = ""

    // Derive current status from last entry; default to "Checked In"
    private var currentStatus: String {
        item.statusHistory.last?.status ?? "Checked In"
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 10) {


            // ───── Status Controls ─────
            HStack(spacing: 10) {
                // Badge shows the latest status, or "Checked In" if empty
                StatusBadge(status: currentStatus)

                // Menu to set a new status
                Menu {
                    Button("Checked In")     { onChangeStatus?(item, "Checked In") }
                    Button("In Progress")    { onChangeStatus?(item, "In Progress") }
                    Button("Done")           { onChangeStatus?(item, "Done") }
                    Button("Tested: PASS")   { onChangeStatus?(item, "Tested: PASS") }
                    Button("Tested: FAIL")   { onChangeStatus?(item, "Tested: FAIL") }
                    Button("Completed")      { onChangeStatus?(item, "Completed") }
                    Button("Closed")         { onChangeStatus?(item, "Closed") }
                } label: {
                    Label("Update Status", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 6)
            // END status controls

            // … (keep your existing Dropdown highlights, Reasons for Service, Thumbnails) …


            // Top row: Type + optional Tag
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.type.isEmpty ? "Item" : item.type)
                    .font(.headline)

                if let tag = item.tagId, !tag.isEmpty {
                    Text("Tag: \(tag)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Dropdown highlights (size, color w/ swatch, machine type/brand, wait time)
            VStack(alignment: .leading, spacing: 6) {
                if let size = item.dropdowns["size"], !size.isEmpty {
                    LabeledRow(icon: "ruler", label: "Size", value: size)
                }

                if let colorName = item.dropdowns["color"], !colorName.isEmpty {
                    let hex = item.dropdowns["colorHex"] ?? ""
                    HStack(spacing: 8) {
                        LabeledRow(icon: "paintpalette.fill", label: "Color", value: colorName)
                        if !hex.isEmpty {
                            ColorDot(hex: hex)
                        }
                    }
                }

                let machineType = item.dropdowns["machineType"] ?? ""
                let machineBrand = item.dropdowns["machineBrand"] ?? ""
                if !machineType.isEmpty || !machineBrand.isEmpty {
                    LabeledRow(
                        icon: "wrench.and.screwdriver.fill",
                        label: "Machine",
                        value: [machineBrand, machineType].filter { !$0.isEmpty }.joined(separator: " • ")
                    )
                }

                if let wait = item.dropdowns["waitTime"], !wait.isEmpty {
                    LabeledRow(icon: "hourglass", label: "Wait", value: wait)
                }
            }

            // Reasons for Service
            if !item.reasonsForService.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reasons for Service")
                        .font(.subheadline.weight(.semibold))
                    // simple bullet list
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(item.reasonsForService, id: \.self) { reason in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                Text(reason)
                            }
                            .font(.footnote)
                        }
                    }

                    if let note = item.reasonNotes, !note.isEmpty {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 6)
            }

            // Thumbnails grid (thumbUrls preferred, fallback to imageUrls)
            let thumbs = !item.thumbUrls.isEmpty ? item.thumbUrls : item.imageUrls
            if !thumbs.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(thumbs, id: \.self) { url in
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 10).fill(.tertiary).overlay(
                                    ProgressView().scaleEffect(0.8)
                                )
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 90)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06)))
                            case .failure:
                                RoundedRectangle(cornerRadius: 10).strokeBorder(.secondary)
                                    .overlay(Image(systemName: "photo"))
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(height: 90)
                    }
                }
                .padding(.top, 4)
            }
            // ───── Notes / Status Timeline ─────
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes / Status Updates")
                    .font(.subheadline.weight(.semibold))

                if item.notes.isEmpty && item.statusHistory.isEmpty {
                    Text("No notes or status updates yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    // Merge WO_Status + WO_Note, sort newest → oldest
                    let statusEntries = item.statusHistory.map { status in
                        (status.timestamp, "\(status.status)\(status.notes.map { " – \($0)" } ?? "")", status.user)
                    }
                    let noteEntries = item.notes.map { note in
                        (note.timestamp, note.text, note.user)
                    }
                    let combined = (statusEntries + noteEntries)
                        .sorted { $0.0 > $1.0 }

                    VStack(spacing: 8) {
                        ForEach(Array(combined.enumerated()), id: \.offset) { _, entry in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "person.fill")
                                    .imageScale(.small)
                                    .opacity(0.7)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(entry.2.isEmpty ? "Tech" : entry.2)
                                            .font(.footnote.weight(.semibold))
                                        Text(entry.0.formatted(date: .abbreviated, time: .shortened))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(entry.1)
                                        .font(.callout)
                                }
                            }
                            .padding(8)
                            .background(.ultraThinMaterial.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                // ───── Composer ─────
                HStack(alignment: .top, spacing: 8) {
                    TextField("Add a note…", text: $newNoteText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)

                    Button {
                        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let author = "Tech" // Replace with appState.currentUserName
                        let note = WO_Note(user: author, text: trimmed, timestamp: Date())
                        onAddNote?(item, trimmed) // persist via parent
                        newNoteText = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#FFC500"))
                }
            }
            .padding(.top, 6)
            // END notes/timeline

        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        // END
    }
}

// ───── Labeled Row (icon + label + value) ─────
private struct LabeledRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .imageScale(.small)
                .frame(width: 16)
                .opacity(0.7)
            Text("\(label):")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
        }
        // END
    }
}

// ───── Color Dot helper ─────
private struct ColorDot: View {
    let hex: String
    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: 14, height: 14)
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.15)))
    }
}
// ───── Note Row (user • time • text) ─────
private struct NoteRow: View {
    let note: WO_Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: user + timestamp
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .imageScale(.small)
                    .opacity(0.7)
                Text(note.user.isEmpty ? "Tech" : note.user)
                    .font(.footnote.weight(.semibold))
                Text(note.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            // Body: the note
            Text(note.text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        // END
    }
}

// ───── Preview Template ─────
#Preview {
    let appState = AppState.shared
    appState.currentUserName = "Preview Manager"
    appState.currentUserRole = .manager
    return WorkOrderDetailView(workOrder: WorkOrder.sample)
        .environmentObject(appState)
}
