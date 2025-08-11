//
//  View+Extensions.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/10/25.
//
// ───── GLOBAL FORM SPACING MODIFIER ─────
import SwiftUI

struct TightFormSpacing: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

extension View {
    /// Applies tighter default spacing between Form sections/rows globally where used
    func tightFormSpacing() -> some View {
        self.modifier(TightFormSpacing())
    }
}

