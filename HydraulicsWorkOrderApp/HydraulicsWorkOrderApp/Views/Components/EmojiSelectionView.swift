//
//  EmojiSelectionView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/11/25.
//

import SwiftUI

// MARK: - Emoji Selection View
struct EmojiSelectionView: View {
    @Binding var selectedEmoji: String?
    
    private let availableEmojis = ["🧨", "🐢", "🌟"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose an emoji tag:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                // No emoji option
                Button(action: {
                    selectedEmoji = nil
                }) {
                    VStack(spacing: 4) {
                        Text("❌")
                            .font(.title)
                        Text("None")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 60, height: 60)
                    .background(selectedEmoji == nil ? Color.blue.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedEmoji == nil ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Available emoji options
                ForEach(availableEmojis, id: \.self) { emoji in
                    Button(action: {
                        selectedEmoji = emoji
                    }) {
                        VStack(spacing: 4) {
                            Text(emoji)
                                .font(.title)
                            Text(emojiDescription(for: emoji))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 60, height: 60)
                        .background(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedEmoji == emoji ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
        }
    }
    
    private func emojiDescription(for emoji: String) -> String {
        switch emoji {
        case "🧨": return "Dynamite"
        case "🐢": return "Turtle"
        case "🌟": return "Star"
        default: return ""
        }
    }
}

#Preview {
    EmojiSelectionView(selectedEmoji: .constant("🧨"))
}
