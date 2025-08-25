//
//  DropdownField.swift
//  HydraulicsWorkOrderApp
//
//  Created by ChatGPT on behalf of Bec Archer
//

import SwiftUI

// ───── Dropdown Option Model ─────
struct DropdownOption: Identifiable, Equatable {
    let id = UUID()
    var label: String
    var value: String
    var colorHex: String? = nil
}

// ───── DropdownField View ─────
struct DropdownField: View {
    var label: String
    var options: [DropdownOption]
    @Binding var selectedValue: String?
    var showColorPickerIfOther: Bool = false
    @Binding var customColor: Color

    // New (backwards-compatible)
    var placeholder: String? = nil          // shown when no selection; defaults to "Select…"
    var showLabel: Bool = false              // whether to render external label text above the control

    var body: some View {
        VStack(alignment: .leading, spacing: showLabel ? 8 : 0) {
            // Optional external label above the control
            if showLabel {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Build a friendly display label for the menu button
            let currentLabel: String = {
                if let sel = selectedValue, let match = options.first(where: { $0.value == sel }) {
                    return match.label
                } else {
                    return placeholder ?? "Select…"
                }
            }()

            Picker(selection: $selectedValue) {
                // Placeholder row so nil has a tag
                Text(placeholder ?? "Select…").tag(nil as String?)

                ForEach(options) { option in
                    HStack {
                        if let hex = option.colorHex, let uiColor = UIColor(hex: hex) {
                            Circle()
                                .fill(Color(uiColor))
                                .frame(width: 12, height: 12)
                        }
                        Text(option.label)
                    }
                    .tag(option.value as String?)
                }
            } label: {
                HStack(spacing: 8) {
                    // If current selection has a color, show the dot in the button, too
                    if let sel = selectedValue,
                       let match = options.first(where: { $0.value == sel }),
                       let hex = match.colorHex,
                       let uiColor = UIColor(hex: hex) {
                        Circle()
                            .fill(Color(uiColor))
                            .frame(width: 12, height: 12)
                    }
                    Text(currentLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .pickerStyle(.menu)
            .id("picker_\(label)") // keep pickers independent

            if showColorPickerIfOther && (selectedValue ?? "") == "Other" {
                ColorPicker("Pick a color", selection: $customColor)
                    .labelsHidden()
            }
        }
    }

}

// ───── UIColor Hex Extension ─────
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// ───── Preview ─────
#Preview(traits: .sizeThatFitsLayout) {
    DropdownFieldPreview()
}

struct DropdownFieldPreview: View {
    @State var selected: String? = "Yellow"
    @State var customColor = Color.yellow
    
    var body: some View {
        DropdownField(
            label: "Color",
            options: [
                DropdownOption(label: "Black", value: "Black", colorHex: "#000000"),
                DropdownOption(label: "Yellow", value: "Yellow", colorHex: "#FFC500"),
                DropdownOption(label: "Other", value: "Other")
            ],
            selectedValue: $selected,
            showColorPickerIfOther: true,
            customColor: $customColor,
            placeholder: "Color",       // inline placeholder when nil selection
            showLabel: false            // hide external label; mimic inline style
        )
    }
}
