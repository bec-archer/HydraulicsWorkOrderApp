import SwiftUI
import UIKit

// ─────────────────────────────────────────────────────────────
// 📄 AddWOItemFormView.swift
// Reusable inline form for each WO_Item (no nested Form)
// ─────────────────────────────────────────────────────────────

struct AddWOItemFormView: View {
    // Binding to the WO_Item we are editing/creating
    @Binding var item: WO_Item

    // ───── Local UI State ─────
    @State private var customColor = Color.yellow
    @State private var reasonNotes = ""
    @State private var reasonOptionsSnapshot: [DropdownOption] = []  // stable per-render snapshot

    // Local selection buffer so Toggles don't mutate the bound array mid-diff
    @State private var selectedReasons: Set<String> = []

    // Used for Firebase Storage pathing; parent passes draft WO id / WO_Number
    var woId: String = "DRAFT"

    // Managers / singletons
    private let dropdowns = DropdownManager.shared

    // ───── BODY ─────
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ───── Photos (uploads full + thumbnail, updates URLs) ─────
            VStack(alignment: .leading, spacing: 8) {
                Text("Photos")
                    .font(.headline)

                // Wrapper added in PhotoCaptureView.swift (expected to exist in project)
                PhotoCaptureUploadView(
                    imageURLs: $item.imageUrls,    // full-size URLs
                    thumbURLs: $item.thumbUrls,    // thumbnail URLs (if your model does not have this, bind to a dummy @State)
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
                // Use the per-view snapshot captured in state; do not declare local lets in a ViewBuilder
                ForEach(reasonOptionsSnapshot, id: \.value) { option in
                    Toggle(option.label, isOn: Binding(
                        get: { selectedReasons.contains(option.value) },
                        set: { isOn in
                            if isOn {
                                selectedReasons.insert(option.value)
                            } else {
                                selectedReasons.remove(option.value)
                            }
                        }
                    ))
                }
            }
            // END reasons grid

            // If "Other" reason selected, show required notes field
            if selectedReasons.contains("Other (opens Service Notes)") || selectedReasons.contains("Other") {
                TextField("Service Notes…", text: $reasonNotes)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: reasonNotes) {
                        item.reasonNotes = reasonNotes
                        DispatchQueue.main.async { item.lastModified = Date() }
                    }
                    .padding(.top, 2)
            }

        }
        // ───── Color Hex Persistence ─────
        .onChange(of: item.dropdowns["color"]) { newValue in
            let trimmed = (newValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

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
            // initialize notes + color + reasons snapshot
            reasonNotes = item.reasonNotes ?? ""
            if let hexColor = item.dropdowns["colorHex"], !hexColor.isEmpty {
                customColor = Color(hex: hexColor)
            }
            reasonOptionsSnapshot = dropdowns.options["reasonsForService"] ?? []
            // Seed local toggle buffer from persisted model to avoid mid-diff array mutations
            selectedReasons = Set(item.reasonsForService)
        }
        .onChange(of: dropdowns.options["reasonsForService"]?.count ?? 0) { _ in
            // refresh on the next runloop to avoid mid-diff updates
            DispatchQueue.main.async {
                reasonOptionsSnapshot = dropdowns.options["reasonsForService"] ?? []
            }
        }
        .onChange(of: selectedReasons) { newValue in
            // Commit buffered selections to the bound model in a single write
            item.reasonsForService = Array(newValue)
            item.lastModified = Date()
        }
        .id(item.id) // stabilize identity across multiple AddWOItemFormView instances
        .padding(12)
    }
    // END .body

    // ───── Helpers ─────
    private func updateColorHexFromCustomColor() {
        if let comps = UIColor(customColor).cgColor.components, comps.count >= 3 {
            let r = Int(round(comps[0] * 255))
            let g = Int(round(comps[1] * 255))
            let b = Int(round(comps[2] * 255))
            item.dropdowns["colorHex"] = String(format: "#%02X%02X%02X", r, g, b)
        }
    }
}
// END AddWOItemFormView

// ───── Preview Template ─────
#Preview {
    // Provide a minimal sample WO_Item; if your project uses a different factory, adjust as needed
    AddWOItemFormView(item: .constant(WO_Item.sample), woId: "WO_PREVIEW")
}
