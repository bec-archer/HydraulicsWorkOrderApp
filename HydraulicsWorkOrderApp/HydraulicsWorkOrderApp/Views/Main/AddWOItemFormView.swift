
//  AddWOItemFormView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//

// ─────────────────────────────────────────────────────────────
// 📄 AddWOItemFormView.swift
// Reusable inline form for each WO_Item (no nested Form)
// ─────────────────────────────────────────────────────────────

import SwiftUI

// ───── AddWOItemFormView ─────
struct AddWOItemFormView: View {
    @Binding var item: WO_Item
    @State private var customColor = Color.yellow
    @State private var reasonNotes = ""

    let dropdowns = DropdownManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ───── TYPE ─────
            DropdownField(
                label: "Type",
                options: dropdowns.options["type"] ?? [],
                selectedValue: Binding(
                    get: { let v = item.dropdowns["type"]; return v?.isEmpty == true ? nil : v },
                    set: { item.dropdowns["type"] = $0 ?? "" }
                ),
                showColorPickerIfOther: false,
                customColor: $customColor
            )

            // ───── SIZE (if Cylinder) ─────
            if (item.dropdowns["type"] ?? "") == "Cylinder" {
                DropdownField(
                    label: "Size",
                    options: dropdowns.options["size"] ?? [],
                    selectedValue: Binding(
                        get: { let v = item.dropdowns["type"]; return v?.isEmpty == true ? nil : v },
                            set: { item.dropdowns["type"] = $0 ?? "" }
                        ),
                    showColorPickerIfOther: false,
                    customColor: $customColor
                )
            }

            // ───── COLOR ─────
            DropdownField(
                label: "Color",
                options: dropdowns.options["color"] ?? [],
                selectedValue: Binding(
                    get: { let v = item.dropdowns["type"]; return v?.isEmpty == true ? nil : v },
                        set: { item.dropdowns["type"] = $0 ?? "" }
                    ),
                showColorPickerIfOther: true, // "Other" opens a ColorPicker
                customColor: $customColor
            )

            // ───── MACHINE TYPE ─────
            DropdownField(
                label: "Machine Type",
                options: dropdowns.options["machineType"] ?? [],
                selectedValue: Binding(
                    get: { let v = item.dropdowns["type"]; return v?.isEmpty == true ? nil : v },
                        set: { item.dropdowns["type"] = $0 ?? "" }
                    ),
                showColorPickerIfOther: false,
                customColor: $customColor
            )

            // ───── MACHINE BRAND ─────
            DropdownField(
                label: "Machine Brand",
                options: dropdowns.options["machineBrand"] ?? [],
                selectedValue: Binding(
                    get: { let v = item.dropdowns["type"]; return v?.isEmpty == true ? nil : v },
                        set: { item.dropdowns["type"] = $0 ?? "" }
                    ),
                showColorPickerIfOther: false,
                customColor: $customColor
            )

            // ───── WAIT TIME ─────
            DropdownField(
                label: "Estimated Wait Time",
                options: dropdowns.options["waitTime"] ?? [],
                selectedValue: Binding(
                    get: { let v = item.dropdowns["type"]; return v?.isEmpty == true ? nil : v },
                        set: { item.dropdowns["type"] = $0 ?? "" }
                    ),
                showColorPickerIfOther: false,
                customColor: $customColor
            )

            // ───── REASONS FOR SERVICE ─────
            Text("Reason(s) for Service")
                .font(.headline)
                .padding(.top, 6)

            ForEach(dropdowns.options["reasonsForService"] ?? []) { option in
                Toggle(option.label, isOn: Binding(
                    get: { item.reasonsForService.contains(option.value) },
                    set: { isOn in
                        if isOn {
                            if !item.reasonsForService.contains(option.value) {
                                item.reasonsForService.append(option.value)
                            }
                        } else {
                            item.reasonsForService.removeAll { $0 == option.value }
                        }
                    }
                ))
            }

            if item.reasonsForService.contains("Other (opens Service Notes)") || item.reasonsForService.contains("Other") {
                TextField("Service Notes…", text: $reasonNotes)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: reasonNotes) { item.reasonNotes = reasonNotes }
                    .padding(.top, 2)
            }
        }
        .padding(12)
        // END .body
    }
}

// ───── Preview Template ─────
#Preview {
    AddWOItemFormView(item: .constant(WO_Item.sample))
}
