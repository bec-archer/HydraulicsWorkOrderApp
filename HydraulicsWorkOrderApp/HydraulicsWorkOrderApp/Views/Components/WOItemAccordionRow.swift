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
    @Binding var expandedIndices: Set<Int>
    @Binding var showValidationNudge: Bool
    let onDelete: (Int) -> Void

    @State private var selectedImage: IdentifiableURL? = nil

    private var isPartial: Bool {
        let item = items[index]
        let hasType = !item.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPhoto = !item.imageUrls.isEmpty || !item.thumbUrls.isEmpty
        return (hasType && !hasPhoto) || (!hasType && hasPhoto)
    }

    var isExpanded: Bool {
        expandedIndices.contains(index)
    }
    
    init(
        index: Int,
        woId: String,
        items: Binding<[WO_Item]>,
        expandedIndices: Binding<Set<Int>>,
        showValidationNudge: Binding<Bool> = .constant(false),
        onDelete: @escaping (Int) -> Void
    ) {
        self.index = index
        self.woId = woId
        self._items = items
        self._expandedIndices = expandedIndices
        self._showValidationNudge = showValidationNudge
        self.onDelete = onDelete
    }

    var body: some View {
        Group {
            if index < items.count {
                VStack(spacing: 0) {
                    HStack {
                        Text(items[index].type)
                            .font(.title3)
                            .bold()

                        Spacer()

                        Button {
                            withAnimation {
                                if isExpanded {
                                    expandedIndices.remove(index)
                                } else {
                                    expandedIndices.insert(index)
                                }
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

                        AddWOItemFormView(
                            item: $items[index],
                            showValidationNudge: $showValidationNudge,
                            woId: woId
                        )
                            .padding(.top, 8)
                    }
                } // END VStack
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow, lineWidth: isPartial ? 3 : 0)
                )
                .sheet(item: $selectedImage) { identifiable in
                    FullScreenImageViewer(
                        imageURL: identifiable.url,
                        isPresented: Binding(
                            get: { selectedImage != nil },
                            set: { if !$0 { selectedImage = nil } }
                        )
                    )
                }
            } else {
                // If the data source changed and this index is stale, render nothing for this row
                EmptyView()
            }
        }
    } // END body
} // END WOItemAccordionRow

// ───── PREVIEW TEMPLATE ─────
#Preview {
    struct PreviewWrapper: View {
        @State private var items: [WO_Item] = [
            WO_Item(
                id: UUID(),
                itemNumber: "250826-001-WOI-001",
                assetTagId: "XYZ123",
                type: "Pump",
                imageUrls: [],
                thumbUrls: [],
                localImages: [],
                dropdowns: [:],
                dropdownSchemaVersion: 1,
                reasonsForService: [],
                reasonNotes: nil,
                completedReasons: [],
                statusHistory: [
                    WO_Status(status: "In Progress", user: "TestUser", timestamp: Date(), notes: nil)
                ],
                notes: [],
                testResult: nil,
                partsUsed: nil,
                hoursWorked: nil,
                estimatedCost: nil,
                finalCost: nil,
                assignedTo: "Tech",
                isFlagged: false,
                tagReplacementHistory: nil
            )
        ]
        @State private var expandedIndices: Set<Int> = [0]
        @State private var showValidationNudge: Bool = false

        var body: some View {
            WOItemAccordionRow(
                index: 0,
                woId: "PREVIEW-WO-ID",
                items: $items,
                expandedIndices: $expandedIndices,
                showValidationNudge: $showValidationNudge,
                onDelete: { _ in }
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
