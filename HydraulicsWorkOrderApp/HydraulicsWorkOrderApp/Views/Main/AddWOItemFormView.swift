import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 AddWOItemFormView.swift
// Reusable inline form for each WO_Item (no nested Form)
// ─────────────────────────────────────────────────────────────
struct AddWOItemFormView: View {
    // ───── Bound Model ─────
    @Binding var item: WO_Item
    // Parent-controlled nudge trigger (set when user attempts to add/save)
    @Binding var showValidationNudge: Bool

    // ───── Local UI State ─────
    @State private var customColor = Color.yellow
    @State private var reasonNotes = ""
    @State private var reasonOptionsSnapshot: [DropdownOption] = []    // stable per-render snapshot
    @State private var selectedReasons: Set<String> = []               // local buffer for toggles

    // Used for Firebase Storage pathing; parent passes draft WO id / WO_Number
    var woId: String = "DRAFT"

    // Tracks interaction with required fields to decide when to show validation nudges
    @State private var hasTouchedRequired = false

    // Managers / singletons
    private let dropdowns = DropdownManager.shared
    
    // ───── BODY ─────
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            photosSection
            typeField
            requiredNudge
            dropdownsGrid
            reasonsSection
            otherReasonNotes
        }
        // ───── Color Hex Persistence ─────
        .onChange(of: item.dropdowns["color"]) { _, newValue in
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
        .onChange(of: customColor) { _, _ in
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

            // If the item already has any data, allow the nudge to render immediately
            hasTouchedRequired = !isBlankItem

            // ⬅️ Don't set a default type - let the dropdown show placeholder
            // if item.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            //     item.type = "Type"
            // }
        }
        .onChange(of: dropdowns.options["reasonsForService"]?.count ?? 0) { _, _ in
            // refresh on the next runloop to avoid mid-diff updates
            DispatchQueue.main.async {
                reasonOptionsSnapshot = dropdowns.options["reasonsForService"] ?? []
            }
        }
        .onChange(of: selectedReasons) { _, newValue in
            // Commit buffered selections to the bound model in a single write
            item.reasonsForService = Array(newValue)
            item.lastModified = Date()
        }
        .id(item.id) // stabilize identity across multiple AddWOItemFormView instances
        .padding(12)
    }
    // END .body

    // ───── Subviews (split to reduce type-check complexity) ─────
    @ViewBuilder private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos")
                .font(.headline)
            PhotoCaptureUploadView(
                imageURLs: $item.imageUrls,
                thumbURLs: $item.thumbUrls,
                woId: woId,
                woItemId: item.id,
                showQR: true,
                onScanQR: {
                    print("Scan QR Code tapped for item \(item.id)")
                },
                onImagesChanged: {
                    hasTouchedRequired = true
                }
            )
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder private var typeField: some View {
        DropdownField(
            label: "Type *",
            options: dropdowns.options["type"] ?? [],
            selectedValue: typeBinding,
            showColorPickerIfOther: false,
            customColor: $customColor,
            placeholder: "Type *",
            showLabel: false,
            onValueChanged: {
                hasTouchedRequired = true
            }
        )
    }

    @ViewBuilder private var requiredNudge: some View {
        if showValidationNudge && isPartiallyFilled {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .imageScale(.large)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Finish Required Fields")
                        .font(.headline)
                    Text("Each WO_Item needs a **Type** and at least **one Photo** before check-in. Add the missing field to continue.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
            )
            .accessibilityLabel("Finish Required Fields: Type and at least one Photo are required.")
        }
    }

    @ViewBuilder private var dropdownsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
            // SIZE (Only if Type == "Cylinder")
            if item.type.caseInsensitiveCompare("Cylinder") == .orderedSame {
                DropdownField(
                    label: "Size",
                    options: dropdowns.options["size"] ?? [],
                    selectedValue: sizeBinding,
                    showColorPickerIfOther: false,
                    customColor: $customColor,
                    placeholder: "Size",
                    showLabel: false
                )
            }

            // COLOR
            DropdownField(
                label: "Color",
                options: dropdowns.options["color"] ?? [],
                selectedValue: colorBinding,
                showColorPickerIfOther: true,
                customColor: $customColor,
                placeholder: "Color",
                showLabel: false
            )

            // MACHINE TYPE
            DropdownField(
                label: "Machine Type",
                options: dropdowns.options["machineType"] ?? [],
                selectedValue: machineTypeBinding,
                showColorPickerIfOther: false,
                customColor: $customColor,
                placeholder: "Machine Type",
                showLabel: false
            )

            // MACHINE BRAND
            DropdownField(
                label: "Machine Brand",
                options: dropdowns.options["machineBrand"] ?? [],
                selectedValue: machineBrandBinding,
                showColorPickerIfOther: false,
                customColor: $customColor,
                placeholder: "Machine Brand",
                showLabel: false
            )

            // WAIT TIME
            DropdownField(
                label: "Estimated Wait Time",
                options: dropdowns.options["waitTime"] ?? [],
                selectedValue: waitTimeBinding,
                showColorPickerIfOther: false,
                customColor: $customColor,
                placeholder: "Wait Time",
                showLabel: false
            )
        }
    }

    @ViewBuilder private var reasonsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reason(s) for Service")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(reasonOptionsSnapshot, id: \.value) { option in
                    Button(action: {
                        if selectedReasons.contains(option.value) {
                            selectedReasons.remove(option.value)
                        } else {
                            selectedReasons.insert(option.value)
                        }
                    }) {
                        Text(option.label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedReasons.contains(option.value) ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedReasons.contains(option.value) ? Color.blue : Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedReasons.contains(option.value) ? Color.blue : Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    @ViewBuilder private var otherReasonNotes: some View {
        if selectedReasons.contains("Other") {
            TextField("Service Notes…", text: $reasonNotes)
                .textFieldStyle(.roundedBorder)
                .onChange(of: reasonNotes) { _, _ in
                    item.reasonNotes = reasonNotes
                    DispatchQueue.main.async { item.lastModified = Date() }
                }
                .padding(.top, 2)
        }
    }
    // END Subviews

    // ───── Local Bindings (computed) ─────
    private var typeBinding: Binding<String?> {
        Binding<String?>(
            get: { item.type.isEmpty ? nil : item.type },
            set: { item.type = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
        )
    }
    private var sizeBinding: Binding<String?> {
        Binding<String?>(
            get: {
                let v = item.dropdowns["size"]
                return (v?.isEmpty == true) ? nil : v
            },
            set: { item.dropdowns["size"] = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
        )
    }
    private var colorBinding: Binding<String?> {
        Binding<String?>(
            get: {
                let v = item.dropdowns["color"]
                return (v?.isEmpty == true) ? nil : v
            },
            set: { item.dropdowns["color"] = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
        )
    }
    private var machineTypeBinding: Binding<String?> {
        Binding<String?>(
            get: {
                let v = item.dropdowns["machineType"]
                return (v?.isEmpty == true) ? nil : v
            },
            set: { item.dropdowns["machineType"] = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
        )
    }
    private var machineBrandBinding: Binding<String?> {
        Binding<String?>(
            get: {
                let v = item.dropdowns["machineBrand"]
                return (v?.isEmpty == true) ? nil : v
            },
            set: { item.dropdowns["machineBrand"] = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
        )
    }
    private var waitTimeBinding: Binding<String?> {
        Binding<String?>(
            get: {
                let v = item.dropdowns["waitTime"]
                return (v?.isEmpty == true) ? nil : v
            },
            set: { item.dropdowns["waitTime"] = $0 ?? ""; DispatchQueue.main.async { item.lastModified = Date() } }
        )
    }
    // END Local Bindings (computed)

    // ───── Required Field Logic (local to view) ─────
    private var hasAtLeastOnePhoto: Bool {
        // Accept either full-size or thumbnail URLs as evidence of a captured photo
        return !item.imageUrls.isEmpty || !item.thumbUrls.isEmpty
    }
    private var isTypeSelected: Bool {
        return !item.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// A "blank" item has neither type nor any photo
    private var isBlankItem: Bool {
        return !hasAtLeastOnePhoto && !isTypeSelected
    }
    /// A "partially filled" item has either type or photo, but not both
    private var isPartiallyFilled: Bool {
        return (hasAtLeastOnePhoto && !isTypeSelected) || (!hasAtLeastOnePhoto && isTypeSelected)
    }
    // END Required Field Logic

    // ───── Reason Toggle Binding Helper ─────
    private func reasonBinding(for value: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { selectedReasons.contains(value) },
            set: { isOn in
                if isOn { selectedReasons.insert(value) }
                else { selectedReasons.remove(value) }
            }
        )
    }
    // END Reason Toggle Binding Helper

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
    // Provide a minimal sample WO_Item; adjust to your factory if needed
    AddWOItemFormView(item: .constant(WO_Item.sample),
                      showValidationNudge: .constant(false),
                      woId: "WO_PREVIEW")
}
