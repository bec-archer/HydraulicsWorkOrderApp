//
//  ThemeManager.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/9/25.
//

import SwiftUI
import Foundation

// ─────────────────────────────────────────────────────────────
// 📄 ThemeManager.swift
// Centralized theme management for AppleNotes_Style_YellowTheme
// Loads theme tokens from AppleNotesYellow.json
// ─────────────────────────────────────────────────────────────

struct ThemeManager {
    static let shared = ThemeManager()
    
    private let themeData: ThemeData
    
    private init() {
        // Load theme from AppleNotesYellow.json
        guard let url = Bundle.main.url(forResource: "AppleNotesYellow", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let themeData = try? JSONDecoder().decode(ThemeData.self, from: data) else {
            // Fallback theme if loading fails
            self.themeData = ThemeData.fallback
            print("⚠️ THEME: Failed to load AppleNotesYellow.json, using fallback theme")
            return
        }
        self.themeData = themeData
        print("✅ THEME: Loaded \(themeData.themeName) successfully")
    }
    
    // MARK: - Colors
    var background: Color { Color(hex: themeData.colors.background) }
    var foreground: Color { Color(hex: themeData.colors.foreground) }
    var textPrimary: Color { Color(hex: themeData.colors.textPrimary) }
    var textSecondary: Color { Color(hex: themeData.colors.textSecondary) }
    var linkColor: Color { Color(hex: themeData.colors.linkColor) }
    var buttonBackground: Color { Color(hex: themeData.colors.buttonBackground) }
    var buttonText: Color { Color(hex: themeData.colors.buttonText) }
    var highlight: Color { Color(hex: themeData.colors.highlight) }
    var border: Color { Color(hex: themeData.colors.border) }
    var disabled: Color { Color(hex: themeData.colors.disabled) }
    
    // MARK: - Cards
    var cardBackground: Color { Color(hex: themeData.cards.background) }
    var cardShadowColor: Color { Color(hex: themeData.cards.shadowColor) }
    var cardShadowOpacity: Double { themeData.cards.shadowOpacity }
    var cardCornerRadius: CGFloat { themeData.cards.cornerRadius }
    
    // MARK: - Buttons
    var buttonCornerRadius: CGFloat { themeData.buttons.cornerRadius }
    var buttonPadding: CGFloat { themeData.buttons.padding }
    var buttonElevation: CGFloat { themeData.buttons.elevation }
    
    // MARK: - Fonts
    var titleFont: Font { 
        Font.system(size: themeData.fonts.title.size, weight: .bold)
    }
    var bodyFont: Font { 
        Font.system(size: themeData.fonts.body.size, weight: .regular)
    }
    var labelFont: Font { 
        Font.system(size: themeData.fonts.label.size, weight: .semibold)
    }
}

// MARK: - Theme Data Models
private struct ThemeData: Codable {
    let themeName: String
    let colors: Colors
    let fonts: Fonts
    let buttons: Buttons
    let cards: Cards
    
    static let fallback = ThemeData(
        themeName: "Fallback Theme",
        colors: Colors(
            background: "#FFFFFF",
            foreground: "#000000",
            textPrimary: "#000000",
            textSecondary: "#4A4A4A",
            linkColor: "#FFC500",
            buttonBackground: "#FFC500",
            buttonText: "#000000",
            highlight: "#FFF8DC",
            border: "#E0E0E0",
            disabled: "#BFBFBF"
        ),
        fonts: Fonts(
            title: FontData(size: 22, weight: "bold"),
            body: FontData(size: 16, weight: "regular"),
            label: FontData(size: 18, weight: "semibold")
        ),
        buttons: Buttons(
            cornerRadius: 12,
            padding: 12,
            elevation: 1
        ),
        cards: Cards(
            background: "#FFFFFF",
            shadowColor: "#888888",
            shadowOpacity: 0.1,
            cornerRadius: 16
        )
    )
}

private struct Colors: Codable {
    let background: String
    let foreground: String
    let textPrimary: String
    let textSecondary: String
    let linkColor: String
    let buttonBackground: String
    let buttonText: String
    let highlight: String
    let border: String
    let disabled: String
}

private struct Fonts: Codable {
    let title: FontData
    let body: FontData
    let label: FontData
}

private struct FontData: Codable {
    let size: CGFloat
    let weight: String
}

private struct Buttons: Codable {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let elevation: CGFloat
}

private struct Cards: Codable {
    let background: String
    let shadowColor: String
    let shadowOpacity: Double
    let cornerRadius: CGFloat
}

