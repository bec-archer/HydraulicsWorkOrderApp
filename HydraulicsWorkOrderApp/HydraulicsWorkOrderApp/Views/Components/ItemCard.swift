//  ItemCard.swift
//  HydraulicsWorkOrderApp

import SwiftUI

// ───── ItemCard View ─────

struct ItemCard: View {
    let item: WO_Item
    var onAddNote: (WO_Item, String) -> Void
    var onChangeStatus: (WO_Item, String) -> Void
    
    @State private var noteText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(item.type) \(item.dropdowns["size"] ?? "")")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor(for: item.statusHistory.last?.status))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    
                    if let color = item.dropdowns["color"] {
                        HStack(spacing: 6) {
                            Text("Color: \(color)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let hex = item.dropdowns["colorHex"] {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 0.5))
                                    .accessibilityLabel("\(color) color swatch")
                            }
                        }
                    }


                    
                    if let brand = item.dropdowns["brand"] {
                        Text("Brand: \(brand)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button("Checked In")  { onChangeStatus(item, "Checked In") }
                    Button("In Progress") { onChangeStatus(item, "In Progress") }
                    Button("Completed")   { onChangeStatus(item, "Completed") }
                    Button("Testing")     { onChangeStatus(item, "Testing") }
                    Button("Approved")    { onChangeStatus(item, "Approved") }
                } label: {
                    Label("Change Status", systemImage: "arrow.triangle.2.circlepath")
                    
                }
            }
            
            // ───── Thumbnail Carousel (scrollable) ─────
            let urls = item.thumbUrls.isEmpty ? item.imageUrls : item.thumbUrls
            
            if !urls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(urls, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipped()
                                        .cornerRadius(10)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 120, height: 120)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 160)
            }
            
            // ───── Status History List ─────
            if !item.statusHistory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status History:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(item.statusHistory, id: \.timestamp) { status in
                        Text("• \(status.status) by \(status.user) @ \(status.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // ───── Notes Timeline ─────
            if !item.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(item.notes, id: \.id) { note in
                        Text("• \(note.text) — \(note.user), \(note.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
        } // END VStack
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // ───── Status-Based Color Mapping ─────
    func statusColor(for status: String?) -> Color {
        switch status?.lowercased() {
        case "checked in":   return UIConstants.StatusColors.checkedIn
        case "disassembly":  return UIConstants.StatusColors.disassembly
        case "in progress":  return UIConstants.StatusColors.inProgress
        case "test failed":  return UIConstants.StatusColors.testFailed
        case "completed":    return UIConstants.StatusColors.completed
        case "closed":       return UIConstants.StatusColors.closed
        default:             return UIConstants.StatusColors.fallback
        }
    } // END
} // END ItemCard


// ───── Preview ─────
#Preview(traits: .sizeThatFitsLayout) {
    ItemCard(
        item: WO_Item(
            id: UUID(),
            tagId: "ABC123",
            type: "Cylinder",
            dropdowns: ["size": "3", "color": "Yellow", "brand": "Deere"],
            reasonsForService: [],
            reasonNotes: nil,
            imageUrls: [],
            thumbUrls: [],
            localImages: [],
            lastModified: Date(),
            dropdownSchemaVersion: 1,
            lastModifiedBy: "PreviewUser",
            statusHistory: [
                WO_Status(status: "Checked In", user: "Maria", timestamp: Date(), notes: nil),
                WO_Status(status: "In Progress", user: "Joe", timestamp: Date(), notes: "Started teardown")
            ],
            notes: [
                WO_Note(id: UUID(), user: "Joe", text: "Needs bushing kit", timestamp: Date())
            ]
        ),
        onAddNote: { _, _ in },
        onChangeStatus: { _, _ in }
    )
    .padding()
}
