//  WOItemAccordionRow.swift
//  HydraulicsWorkOrderApp

import SwiftUI

// ───── WRAPPER FOR SHEET ─────
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// ───── ACCORDION ROW FOR EACH ITEM ─────
struct WOItemAccordionRow: View {
    let index: Int
    let woId: String
    @Binding var items: [WO_Item]
    @Binding var expandedIndex: Int?
    let onDelete: (Int) -> Void

    @State private var selectedImage: IdentifiableURL? = nil

    var isExpanded: Bool {
        expandedIndex == index
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(items[index].type)
                    .font(.title3)
                    .bold()

                Spacer()

                Button {
                    withAnimation {
                        expandedIndex = isExpanded ? nil : index
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.gray)
                }

                // 🗑 Delete Button
                Button(role: .destructive) {
                    onDelete(index)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .padding(.leading, 4)
            }
            .contentShape(Rectangle())

            if isExpanded {
                Divider()

                AddWOItemFormView(item: $items[index], woId: woId)
                    .padding(.top, 8)

            }
        } // END VStack
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
        .sheet(item: $selectedImage) { identifiable in
            FullScreenImageViewer(
                imageURL: identifiable.url,
                isPresented: Binding(
                    get: { selectedImage != nil },
                    set: { if !$0 { selectedImage = nil } }
                )
            )
        }
    } // END body
} // END WOItemAccordionRow

// ───── PREVIEW TEMPLATE ─────
#Preview {
    struct PreviewWrapper: View {
        @State private var items: [WO_Item] = [
            WO_Item(
                id: UUID(),
                tagId: "XYZ123",
                imageUrls: [],
                thumbUrls: [],
                type: "Pump",
                dropdowns: [:],
                dropdownSchemaVersion: 1,
                reasonsForService: [],
                reasonNotes: nil,
                statusHistory: [
                    WO_Status(status: "In Progress", user: "TestUser", timestamp: Date(), notes: nil)
                ],
                testResult: nil,
                partsUsed: nil,
                hoursWorked: nil,
                cost: nil,
                assignedTo: "Tech",
                isFlagged: false,
                tagReplacementHistory: nil
            )
        ]
        @State private var expandedIndex: Int? = 0

        var body: some View {
            WOItemAccordionRow(
                index: 0,
                woId: "PREVIEW-WO-ID",
                items: $items,
                expandedIndex: $expandedIndex,
                onDelete: { _ in }
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
