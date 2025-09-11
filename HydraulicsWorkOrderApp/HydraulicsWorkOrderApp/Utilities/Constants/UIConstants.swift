//
//  UIConstants.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 UIConstants.swift
// Centralized UI styles (colors, fonts, padding) from AppleNotesYellow.json
// ─────────────────────────────────────────────────────────────

struct UIConstants {

    // ───── Theme Colors (loaded from AppleNotesYellow.json) ─────
    struct Colors {
        static let yellow = Color(hex: "#FFC500")
        static let border = Color(hex: "#E0E0E0")
        static let textPrimary = Color.black
    }
    // ───── Status Colors ─────
    struct StatusColors {
        static let checkedIn    = Color.blue
        static let disassembly  = Color.purple
        static let inProgress   = Color(hex: "#FFC500") // Yellow
        static let testFailed   = Color.red
        static let completed    = Color.green
        static let closed       = Color.gray
        static let fallback     = Color.secondary
    }

    // ───── Reusable Button Styles ─────
    struct Buttons {

        /// Yellow pill button with black text, matching Apple Notes theme
        static func yellowButtonStyle() -> some ViewModifier {
            return YellowButtonModifier()
        }

        private struct YellowButtonModifier: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .font(.callout)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Colors.yellow)
                    )
                    .foregroundColor(Colors.textPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Colors.border)
                    )
            }
        }
    }
}
// END
