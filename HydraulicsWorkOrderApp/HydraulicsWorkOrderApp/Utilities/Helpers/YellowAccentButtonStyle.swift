//
//  YellowAccentButtonStyle.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//


//
//  YellowAccentButtonStyle.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import SwiftUI

// ───── Reusable Filled Yellow Button Style ─────
struct YellowAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)                            // large, legible
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.7725, blue: 0.0)) // #FFC500
                    .opacity(configuration.isPressed ? 0.85 : 1.0)
            )
            .foregroundStyle(.black)
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
// END

// ───── Preview Template ─────
#Preview {
    VStack(spacing: 20) {
        Button("+ New Work Order") {}
            .buttonStyle(YellowAccentButtonStyle())
        Button("Secondary Action") {}
            .buttonStyle(YellowAccentButtonStyle())
    }
    .padding()
}
