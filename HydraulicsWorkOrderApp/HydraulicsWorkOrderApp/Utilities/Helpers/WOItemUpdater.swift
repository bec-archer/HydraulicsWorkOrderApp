//
//  WOItemUpdater.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/18/25.
//


//  WOItemUpdater.swift
//  HydraulicsWorkOrderApp
//
//  Created to encapsulate reusable WO_Item update logic (notes + statuses)

import Foundation

struct WOItemUpdater {

    // ───── Add Note to WO_Item ─────
    static func addNote(
        to workOrder: inout WorkOrder,
        itemId: UUID,
        note: WO_Note
    ) {
        guard let idx = workOrder.items.firstIndex(where: { $0.id == itemId }) else { return }
        workOrder.items[idx].notes.append(note)
        workOrder.lastModified = note.timestamp
        workOrder.lastModifiedBy = note.user

        if !workOrder.id.isEmpty {
            let workOrderId = workOrder.id
            Task { @MainActor in
                WorkOrdersDatabase.shared.addItemNote(note, to: workOrderId, completion: { result in
                    switch result {
                    case .success():
                        print("✅ Note saved for item \(itemId)")
                    case .failure(let err):
                        print("❌ Failed to save note: \(err.localizedDescription)")
                    }
                })
            }
        }
    }

    // ───── Add Status Change to WO_Item ─────
    static func updateStatus(
        of workOrder: inout WorkOrder,
        itemId: UUID,
        newStatus: String,
        user: String
    ) {
        guard let idx = workOrder.items.firstIndex(where: { $0.id == itemId }) else { return }
        let ts = Date()

        let statusEntry = WO_Status(status: newStatus, user: user, timestamp: ts, notes: nil)
        let noteEntry = WO_Note(workOrderId: workOrder.id, user: user, text: "Status changed to \(newStatus)", timestamp: ts)

        workOrder.items[idx].statusHistory.append(statusEntry)
        workOrder.items[idx].notes.append(noteEntry)
        workOrder.lastModified = ts
        workOrder.lastModifiedBy = user

        if !workOrder.id.isEmpty {
            let workOrderId = workOrder.id
            Task { @MainActor in
                WorkOrdersDatabase.shared.updateItemStatusAndNote(newStatus, note: noteEntry, for: workOrderId, completion: { result in
                    switch result {
                    case .success():
                        print("✅ Status update saved for item \(itemId)")
                    case .failure(let err):
                        print("❌ Failed to save status update: \(err.localizedDescription)")
                    }
                })
            }
        }
    }
}
