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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("WO #\(workOrder.WO_Number)")
                    .font(.title)

                if workOrder.flagged {
                    Label("Flagged", systemImage: "flag.fill")
                        .foregroundColor(.red)
                }

                Text("Status: \(workOrder.status)")
                // ───── Tappable Phone (call + context menu for text) ─────
                HStack(spacing: 8) {
                    Text("Phone:")
                    Button {
                        let digits = workOrder.customerPhone.filter(\.isNumber)
                        if let telURL = URL(string: "tel://\(digits)") {
                            UIApplication.shared.open(telURL)
                        }
                    } label: {
                        Text(workOrder.customerPhone)
                            .foregroundColor(Color(hex: "#FFC500"))   // Apple‑Notes yellow accent
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Text") {
                            let digits = workOrder.customerPhone.filter(\.isNumber)
                            if let smsURL = URL(string: "sms:\(digits)") {
                                UIApplication.shared.open(smsURL)
                            }
                        }
                    }
                }
                // END tappable phone

                Text("Created: \(workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))")

                Divider()

                Text("Items:")
                    .font(.headline)

                ForEach(workOrder.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Type: \(item.type)")
                        if let tag = item.tagId {
                            Text("  Tag: \(tag)")
                        }
                        if let reason = item.reasonsForService.first {
                            Text("  Reason: \(reason)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
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
                // Parent should mark isDeleted = true and sync, then we pop back.
                onDelete?(workOrder)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the WorkOrder from Active. Managers/Admins can still access it in Deleted WorkOrders.")
        }
        // END .body
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
