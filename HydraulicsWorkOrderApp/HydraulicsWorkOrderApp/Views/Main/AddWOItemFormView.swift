//
//  AddWOItemFormView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 AddWOItemFormView.swift
// Reusable inline form for each WO_Item
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct AddWOItemFormView: View {
    @Binding var item: WO_Item

    var body: some View {
        Section(header: Text("Equipment Item")) {
            TextField("Tag ID (QR/Serial)", text: Binding(
                get: { item.tagId ?? "" },
                set: { item.tagId = $0.isEmpty ? nil : $0 }
            ))

            TextField("Type (e.g. Pump, Hose)", text: $item.type)

            TextField("Reason for Service", text: Binding(
                get: { item.reasonsForService.first ?? "" },
                set: { item.reasonsForService = [$0] }
            ))

            Toggle("Flag this Item", isOn: $item.isFlagged)
        }
    }
}
