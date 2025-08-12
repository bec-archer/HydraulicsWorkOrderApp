//  AddWOItemFormView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.

// ─────────────────────────────────────────────────────────────
// 📄 AddWOItemFormView.swift
// Reusable inline form for each WO_Item (no nested Form)
// ─────────────────────────────────────────────────────────────

import SwiftUI
import UIKit
import FirebaseStorage    // ⬅️ for debug listing

// ───── AddWOItemFormView ─────
struct AddWOItemFormView: View {
    @Binding var item: WO_Item
    @State private var customColor = Color.yellow
    @State private var reasonNotes = ""

    // Used for Firebase Storage pathing; parent can pass draftWOId/WO_Number
    var woId: String = "DRAFT"


    // ───── WorkOrder context (handled by `var woId` above) ─────
    // (Removed duplicate `let woId`; we keep the single `var woId: String = "DRAFT"`)


    // ───── Temporary sink for thumbnail URLs (Option 1: no schema change yet) ─────
    @State private var trashThumbs: [String] = []

    let dropdowns = DropdownManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // ───── Photos (uploads full + thumbnail, updates URLs) ─────
            VStack(alignment: .leading, spacing: 8) {
                Text("Photos")
                    .font(.headline)

                // Uses the wrapper you added in PhotoCaptureView.swift
                PhotoCaptureUploadView(
                    imageURLs: $item.imageUrls,    // full-size URLs
                    thumbURLs: $item.thumbUrls,    // thumbnail URLs
                    woId: woId,
                    woItemId: item.id,
                    showQR: true,
                    onScanQR: {
                        // TODO: Implement QR code scanner logic
                        print("Scan QR Code tapped for item \(item.id)")
                    }
                )

            }
            .padding(.bottom, 8)
            // END Photos
#if DEBUG
// ───── DEBUG: Show URLs captured on this WO_Item ─────
Button {
    debugPrintItemURLs()
} label: {
    Text("🔎 Debug: Print image URLs for This WO_Item")
        .font(.subheadline)
}
.buttonStyle(.bordered)
.padding(.bottom, 8)
// END DEBUG
#endif



            // ───── TYPE (Required) ─────
            DropdownField(

                label: "Type *", // visually indicate required
                options: dropdowns.options["type"] ?? [],
                selectedValue: Binding(
                    get: { item.type.isEmpty ? nil : item.type },
                    set: { item.type = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
                ),
                showColorPickerIfOther: false,
                customColor: $customColor
            )

            // ───── DROPDOWNS GRID (iPad: 2 columns, iPhone: stacks naturally) ─────
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {

                // SIZE (Only if Type == "Cylinder")
                if item.type.caseInsensitiveCompare("Cylinder") == .orderedSame {
                    DropdownField(
                        label: "Size",
                        options: dropdowns.options["size"] ?? [],
                        selectedValue: Binding(
                            get: { let v = item.dropdowns["size"]; return v?.isEmpty == true ? nil : v },
                            set: { item.dropdowns["size"] = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
                        ),
                        showColorPickerIfOther: false,
                        customColor: $customColor
                    )
                }

                // COLOR
                DropdownField(
                    label: "Color",
                    options: dropdowns.options["color"] ?? [],
                    selectedValue: Binding(
                        get: { let v = item.dropdowns["color"]; return v?.isEmpty == true ? nil : v },
                        set: { item.dropdowns["color"] = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
                    ),
                    showColorPickerIfOther: true,
                    customColor: $customColor
                )

                // MACHINE TYPE
                DropdownField(
                    label: "Machine Type",
                    options: dropdowns.options["machineType"] ?? [],
                    selectedValue: Binding(
                        get: { let v = item.dropdowns["machineType"]; return v?.isEmpty == true ? nil : v },
                        set: { item.dropdowns["machineType"] = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
                    ),
                    showColorPickerIfOther: false,
                    customColor: $customColor
                )

                // MACHINE BRAND
                DropdownField(
                    label: "Machine Brand",
                    options: dropdowns.options["machineBrand"] ?? [],
                    selectedValue: Binding(
                        get: { let v = item.dropdowns["machineBrand"]; return v?.isEmpty == true ? nil : v },
                        set: { item.dropdowns["machineBrand"] = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
                    ),
                    showColorPickerIfOther: false,
                    customColor: $customColor
                )

                // WAIT TIME
                DropdownField(
                    label: "Estimated Wait Time",
                    options: dropdowns.options["waitTime"] ?? [],
                    selectedValue: Binding(
                        get: { let v = item.dropdowns["waitTime"]; return v?.isEmpty == true ? nil : v },
                        set: { item.dropdowns["waitTime"] = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
                    ),
                    showColorPickerIfOther: false,
                    customColor: $customColor
                )
            }
            // END DROPDOWNS GRID


            // ───── REASONS FOR SERVICE ─────
            Text("Reason(s) for Service")
                .font(.headline)
                .padding(.top, 6)

            // Two-column grid of toggles
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(dropdowns.options["reasonsForService"] ?? []) { option in
                    Toggle(option.label, isOn: Binding(
                        get: { item.reasonsForService.contains(option.value) },
                        set: { isOn in
                            if isOn {
                                if !item.reasonsForService.contains(option.value) {
                                    item.reasonsForService.append(option.value)
                                    DispatchQueue.main.async { item.lastModified = Date() }
                                }
                            } else {
                                item.reasonsForService.removeAll { $0 == option.value }
                                DispatchQueue.main.async { item.lastModified = Date() }
                            }
                        }
                    ))
                }
            }
            // END reasons grid


            if item.reasonsForService.contains("Other (opens Service Notes)") || item.reasonsForService.contains("Other") {
                TextField("Service Notes…", text: $reasonNotes)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: reasonNotes) { newValue in
                        item.reasonNotes = newValue; DispatchQueue.main.async { item.lastModified = Date() }
                    }
                    .padding(.top, 2)
            }
        }
        // ───── Color Hex Persistence ─────
        .onChange(of: item.dropdowns["color"] ?? "") { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                item.dropdowns["colorHex"] = ""
            } else if let hex = dropdowns.options["color"]?.first(where: { $0.value == trimmed })?.colorHex {
                item.dropdowns["colorHex"] = hex
            } else if trimmed.caseInsensitiveCompare("Other") == .orderedSame {
                updateColorHexFromCustomColor()
            } else {
                item.dropdowns["colorHex"] = ""
            }
        }
        .onChange(of: customColor) { _ in
            let isOther = (item.dropdowns["color"] ?? "").caseInsensitiveCompare("Other") == .orderedSame
            if isOther { updateColorHexFromCustomColor() }
        }
        .onAppear {
            reasonNotes = item.reasonNotes ?? ""
            if let hexColor = item.dropdowns["colorHex"], !hexColor.isEmpty {
                customColor = Color(hex: hexColor)
            }
        }
        .padding(12)
    }
    // ───── DEBUG Helper: list Storage paths for this WO_Item ─────
    // ───── DEBUG Helper: print the URLs stored on this WO_Item ─────
    private func debugPrintItemURLs() {
        print("🔎 WO_Item \(item.id) in WO \(woId)")
        if item.thumbUrls.isEmpty && item.imageUrls.isEmpty {
            print("ℹ️ No URLs on item yet. Take/choose a photo and try again.")
        } else {
            item.thumbUrls.enumerated().forEach { idx, url in
                print("🖼 thumb[\(idx)]: \(url)")
            }
            item.imageUrls.enumerated().forEach { idx, url in
                print("🖼 image[\(idx)]: \(url)")
            }
        }
    }

    // END DEBUG Helper

    // Helper function to update color hex
    private func updateColorHexFromCustomColor() {
        if let comps = UIColor(customColor).cgColor.components, comps.count >= 3 {
            let r = Int(round(comps[0] * 255))
            let g = Int(round(comps[1] * 255))
            let b = Int(round(comps[2] * 255))
            item.dropdowns["colorHex"] = String(format: "#%02X%02X%02X", r, g, b)
        }
    }
}

// ───── Preview Template ─────
#Preview {
    AddWOItemFormView(item: .constant(WO_Item.sample), woId: "WO_PREVIEW")
}
