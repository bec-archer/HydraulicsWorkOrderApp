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

// ───── AddWOItemFormView ─────
struct AddWOItemFormView: View {
    @Binding var item: WO_Item
    @State private var customColor = Color.yellow
    @State private var reasonNotes = ""

    let dropdowns = DropdownManager.shared

    var body: some View {
        Form {
            // ───── TYPE ─────
            DropdownField(
                label: "Type",
                options: dropdowns.options["type"] ?? [],
                selectedValue: Binding(
                    get: { item.dropdowns["type"] ?? "" },
                    set: { item.dropdowns["type"] = $0 }
                ),
                showColorPickerIfOther: false,
                customColor: $customColor
            )

            // ───── SIZE (if Cylinder) ─────
            if item.dropdowns["type"] == "Cylinder" {
                DropdownField(
                    label: "Size",
                    options: dropdowns.options["size"] ?? [],
                    selectedValue: Binding(
                        get: { item.dropdowns["size"] ?? "" },
                        set: { item.dropdowns["size"] = $0 }
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
                    get: { item.dropdowns["color"] ?? "" },
                    set: { item.dropdowns["color"] = $0 }
                ),
                showColorPickerIfOther: true,
                customColor: $customColor
            )

            // ───── MACHINE TYPE ─────
            DropdownField(
                label: "Machine Type",
                options: dropdowns.options["machineType"] ?? [],
                selectedValue: Binding(
                    get: { item.dropdowns["machineType"] ?? "" },
                    set: { item.dropdowns["machineType"] = $0 }
                ),
                showColorPickerIfOther: false,
                customColor: $customColor
            )

            // ───── MACHINE BRAND ─────
            DropdownField(
                label: "Machine Brand",
                options: dropdowns.options["machineBrand"] ?? [],
                selectedValue: Binding(
                    get: { item.dropdowns["machineBrand"] ?? "" },
                    set: { item.dropdowns["machineBrand"] = $0 }
                ),
                showColorPickerIfOther: false,
                customColor: $customColor
            )

            // ───── REASONS FOR SERVICE ─────
            Section(header: Text("Reason(s) for Service")) {
                ForEach(dropdowns.options["reasonsForService"] ?? []) { option in
                    Toggle(option.label, isOn: Binding(
                        get: {
                            item.reasonsForService.contains(option.value)
                        },
                        set: { isOn in
                            if isOn {
                                item.reasonsForService.append(option.value)
                            } else {
                                item.reasonsForService.removeAll { $0 == option.value }
                            }
                        }
                    ))
                }

                if item.reasonsForService.contains("Other") {
                    TextField("Enter custom reason...", text: $reasonNotes)
                        .onChange(of: reasonNotes) {
                            item.reasonNotes = reasonNotes
                        }
                }
            }

            // ───── FLAG TOGGLE ─────
            Section {
                Toggle("Flag this Item", isOn: $item.isFlagged)
            }
        }
        // END .body
    }
}

// ───── Preview Template ─────
#Preview {
    AddWOItemFormView(item: .constant(WO_Item.sample))
}
