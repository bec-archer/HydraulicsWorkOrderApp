//  ItemCard.swift
//  HydraulicsWorkOrderApp

import SwiftUI

// ───── ITEM CARD ─────
struct ItemCard: View {
    let item: WO_Item
    var onImageTap: ((URL) -> Void)? = nil
    var onAddNote: ((WO_Item, WO_Note) -> Void)? = nil
    var onChangeStatus: ((WO_Item, String) -> Void)? = nil

    @State private var showingAddNote = false
    @State private var noteText: String = ""
    @State private var selectedStatus: String = ""

    let statusOptions: [String] = [
        "Checked In",
        "In Progress",
        "Done",
        "Tested: PASS",
        "Tested: FAIL",
        "Completed",
        "Closed"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ───── Tappable Thumbnail Image ─────
            if
                let thumbStr = item.thumbUrls.first,
                let fullStr = item.imageUrls.first,
                let thumbURL = URL(string: thumbStr),
                let fullURL = URL(string: fullStr)
            {
                Button(action: {
                    onImageTap?(fullURL)
                }) {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 200, height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 200, height: 200)
                                .clipped()
                                .cornerRadius(12)
                        case .failure:
                            Color.gray
                                .frame(width: 200, height: 200)
                                .cornerRadius(12)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            // END Thumbnail



            // ───── Item Type & Status ─────
            Text(item.type)
                .font(.headline)

            let currentStatus = item.statusHistory.last?.status ?? "None"
            Text("Status: \(currentStatus)")
                .font(.subheadline)
                .foregroundColor(.gray)

            // ───── Status Change Picker ─────
            if let onChangeStatus = onChangeStatus {
                Picker("Update Status", selection: $selectedStatus) {
                    ForEach(statusOptions, id: \.self) { status in
                        Text(status).tag(status)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedStatus) { newStatus in
                    guard !newStatus.isEmpty else { return }
                    onChangeStatus(item, newStatus)
                }
            }

            // ───── Add Note Button ─────
            if let onAddNote = onAddNote {
                Button {
                    showingAddNote = true
                } label: {
                    Label("Add Note", systemImage: "plus.bubble")
                        .font(.subheadline)
                        .padding(.top, 6)
                }
                .sheet(isPresented: $showingAddNote) {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Text("New Note")
                                .font(.headline)

                            TextEditor(text: $noteText)
                                .frame(height: 120)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3))
                                )

                            Spacer()

                            Button("Save Note") {
                                let user = "Tech"
                                let note = WO_Note(id: UUID(), user: user, text: noteText, timestamp: Date())
                                onAddNote(item, note)
                                noteText = ""
                                showingAddNote = false
                            }
                            .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingAddNote = false
                                }
                            }
                        }
                    }
                }
            }

        } // END VStack
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    } // END body
} // END ItemCard

// ───── PREVIEW TEMPLATE ─────
#Preview {
    let statusHistory: [WO_Status] = [
        WO_Status(status: "Checked In", user: "Maria", timestamp: Date(), notes: nil)
    ]

    let sampleItem = WO_Item(
        id: UUID(),
        tagId: "ABC123",
        imageUrls: ["https://example.com/full.jpg"],
        thumbUrls: ["https://example.com/thumb.jpg"],
        type: "Cylinder",
        dropdowns: [:],
        dropdownSchemaVersion: 1,
        reasonsForService: [],
        reasonNotes: nil,
        statusHistory: statusHistory,
        testResult: nil,
        partsUsed: nil,
        hoursWorked: nil,
        cost: nil,
        assignedTo: "Tech",
        isFlagged: false,
        tagReplacementHistory: nil
    )

    return ItemCard(
        item: sampleItem,
        onImageTap: { url in
            print("TAPPED IMAGE URL: \(url)")
        },
        onAddNote: { _, _ in },
        onChangeStatus: { _, _ in }
    )

}
