
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(label, selection: $selectedValue) {
                // ───── Placeholder so nil has a matching tag ─────
                Text("Select…").tag(nil as String?)

                ForEach(options) { option in

                    HStack {
                        if let hex = option.colorHex, let uiColor = UIColor(hex: hex) {
                            Circle()
                                .fill(Color(uiColor))
                                .frame(width: 12, height: 12)
                        }
                        Text(option.label)
                        }
                        .tag(option.value as String?)   // match Binding<String?>

                }
            }
            .pickerStyle(MenuPickerStyle())

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
    @Previewable @State var selected: String? = "Yellow"   // ← make optional
    @Previewable @State var customColor = Color.yellow

    DropdownField(                                       // ← no 'return' in ViewBuilder
        label: "Color",
        options: [
            DropdownOption(label: "Black", value: "Black", colorHex: "#000000"),
            DropdownOption(label: "Yellow", value: "Yellow", colorHex: "#FFC500"),
            DropdownOption(label: "Other", value: "Other")
        ],
        selectedValue: $selected,
        showColorPickerIfOther: true,
        customColor: $customColor
    )
}
