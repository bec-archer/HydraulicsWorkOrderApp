//
//  AddWOItemView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 AddWOItemView.swift
// Form to add a single WO_Item into a WorkOrder
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct AddWOItemView: View {
    @Environment(\.dismiss) var dismiss

    // Binding to update items in parent
    @Binding var items: [WO_Item]

    // ───── Fields ─────
    @State private var tagId: String = ""
    @State private var type: String = ""
    @State private var reason: String = ""
    @State private var isFlagged = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Equipment Info")) {
                    TextField("Tag ID (QR/Serial)", text: $tagId)
                    TextField("Type (e.g. Pump, Hose)", text: $type)
                }

                Section(header: Text("Reason for Service")) {
                    TextField("e.g. Leaking, Reseal", text: $reason)
                    Toggle("Flag this Item", isOn: $isFlagged)
                }

                Section {
                    Button("➕ Add Item") {
                        addItem()
                    }
                }
            }
            .navigationTitle("Add Equipment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        // END .body
    }

    // ───── Save Handler ─────
    func addItem() {
        guard !type.isEmpty else { return }

        let newItem = WO_Item(
            id: UUID(),
            itemNumber: nil,  // Will be set when added to work order
            assetTagId: tagId.isEmpty ? nil : tagId,
            type: type,
            imageUrls: [],
            thumbUrls: [],
            localImages: [],
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            reasonsForService: reason.isEmpty ? [] : [reason],
            reasonNotes: nil,
            completedReasons: [],
            statusHistory: [],
            notes: [],
            testResult: nil,
            partsUsed: nil,
            hoursWorked: nil,
            estimatedCost: nil,
            finalCost: nil,
            assignedTo: "",
            isFlagged: isFlagged,
            tagReplacementHistory: nil
        )

        items.append(newItem)
        dismiss()
    }


    // END
}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    AddWOItemView(items: .constant([]))
}
