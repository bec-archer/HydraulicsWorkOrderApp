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

        if let woId = workOrder.id {
            WorkOrdersDatabase.shared.addItemNote(
                woId: woId,
                itemId: itemId,
                note: note
            ) { result in
                switch result {
                case .success():
                    print("✅ Note saved for item \(itemId)")
                case .failure(let err):
                    print("❌ Failed to save note: \(err.localizedDescription)")
                }
            }
        }
    }

    // ───── Add Status Change to WO_Item ─────
    static func updateStatus(
        of workOrder: inout WorkOrder,
        itemId: UUID,
        newStatus: String,
        user: String = "Tech"
    ) {
        guard let idx = workOrder.items.firstIndex(where: { $0.id == itemId }) else { return }
        let ts = Date()

        let statusEntry = WO_Status(status: newStatus, user: user, timestamp: ts, notes: nil)
        let noteEntry = WO_Note(user: user, text: "Status changed to \(newStatus)", timestamp: ts)

        workOrder.items[idx].statusHistory.append(statusEntry)
        workOrder.items[idx].notes.append(noteEntry)
        workOrder.lastModified = ts
        workOrder.lastModifiedBy = user

        if let woId = workOrder.id {
            WorkOrdersDatabase.shared.updateItemStatusAndNote(
                woId: woId,
                itemId: itemId,
                status: statusEntry,
                mirroredNote: noteEntry
            ) { result in
                switch result {
                case .success():
                    print("✅ Status update saved for item \(itemId)")
                case .failure(let err):
                    print("❌ Failed to save status update: \(err.localizedDescription)")
                }
            }
        }
    }
}
