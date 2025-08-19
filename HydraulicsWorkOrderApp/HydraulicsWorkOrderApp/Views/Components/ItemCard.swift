//  ItemCard.swift
//  HydraulicsWorkOrderApp

import SwiftUI

// ───── Image URL Resolver (thumb → full) ─────
// Returns a valid URL for the tapped index, preferring full-size imageUrls,
// falling back to thumbUrls if needed. Logs what was tapped (temporary).
private func resolvedURL(for item: WO_Item, at index: Int) -> URL? {
    if item.imageUrls.indices.contains(index) {
        let full = item.imageUrls[index]
        if let url = URL(string: full), !full.isEmpty {
            print("🖼️ tapped(full): \(full)") // TEMP logger
            return url
        }
    }
    if item.thumbUrls.indices.contains(index) {
        let thumb = item.thumbUrls[index]
        if let url = URL(string: thumb), !thumb.isEmpty {
            print("🖼️ tapped(thumb): \(thumb)") // TEMP logger
            return url
        }
    }
    if let first = item.imageUrls.first, let url = URL(string: first), !first.isEmpty {
        print("🖼️ tapped(fallback-first): \(first)") // TEMP logger
        return url
    }
    print("🖼️ tapped: no valid URL at index \(index)")
    return nil
}

// ───── ITEM CARD ─────
struct ItemCard: View {
    let item: WO_Item

    // Bindings into the item's image arrays so uploads attach to THIS item
    @Binding var imageURLs: [String]
    @Binding var thumbURLs: [String]

    // Context for upload pathing
    let woId: String?

    var onImageTap: ((URL) -> Void)? = nil
    var onAddNote: ((WO_Item, WO_Note) -> Void)? = nil
    var onChangeStatus: ((WO_Item, String) -> Void)? = nil

    @State private var showingAddNote = false
    @State private var noteText: String = ""
    @State private var selectedStatus: String = ""
    @State private var stagedImages: [UIImage] = []
    @State private var isSavingNote = false


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

            // ───── Tappable Thumbnail Images ─────
            ForEach(Array(item.thumbUrls.enumerated()), id: \.offset) { idx, thumbStr in
                if let thumbURL = URL(string: thumbStr) {
                    Button(action: {
                        if let url = resolvedURL(for: item, at: idx) {
                            onImageTap?(url)
                        } else {
                            print("❌ No resolvable URL for item \(item.id) at index \(idx)")
                        }
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
            }
            // END Thumbnails

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

            // ───── Add Note/Image Button ─────
            if let onAddNote = onAddNote {
                Button {
                    showingAddNote = true
                } label: {
                    Label("Add Note/Image", systemImage: "plus.bubble")
                        .font(.subheadline)
                        .padding(.top, 6)
                }
                .sheet(isPresented: $showingAddNote) {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Text("New Note / Image")
                                .font(.headline)

                            // Note text
                            TextEditor(text: $noteText)
                                .frame(height: 120)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3))
                                )

                            // Inline image capture (staged locally; upload happens on Save)
                            PhotoCaptureView(images: $stagedImages)

                            Spacer()

                            Button {
                                Task {
                                    isSavingNote = true

                                    var uploadedURLs: [String] = []

                                    // Upload staged images sequentially before saving the note
                                    for uiimg in stagedImages {
                                        let prepared = compressForFirebase(uiimg)   // helper below
                                        do {
                                            // Keep full-size URL on the note. (Your StorageManager returns (full, thumb).)
                                            let (fullURL, _) = try await StorageManager.shared
                                                .uploadWOItemImageWithThumbnail(prepared, woId: woId ?? "WO_UNKNOWN", woItemId: item.id)
                                            uploadedURLs.append(fullURL)
                                        } catch {
                                            print("❌ Upload failed: \(error.localizedDescription)")
                                        }
                                    }

                                    // Build WO_Note that carries these image URLs (do NOT append to item.imageUrls)
                                    let user = "Tech"
                                    let note = WO_Note(
                                        user: user,
                                        text: noteText,
                                        timestamp: Date(),
                                        imageURLs: uploadedURLs
                                    )

                                    // Persist via parent (already appends note to the item and writes DB)
                                    onAddNote(item, note)

                                    // Reset & dismiss
                                    noteText = ""
                                    stagedImages.removeAll()
                                    isSavingNote = false
                                    showingAddNote = false
                                }
                            } label: {
                                if isSavingNote {
                                    ProgressView().padding(.vertical, 6)
                                } else {
                                    Text("Save").bold()
                                }
                            }
                            .disabled(isSavingNote || (noteText.trimmingCharacters(in: .whitespaces).isEmpty && stagedImages.isEmpty))
                            .buttonStyle(.borderedProminent)

                        }
                        .padding()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showingAddNote = false }
                            }
                        }
                    }
                }
            }

            // END Add Note/Image Button

        } // END VStack
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    } // END body
} // END ItemCard
// ───── Local helper used only in note save ─────
private func compressForFirebase(_ image: UIImage) -> UIImage {
    let maxEdge: CGFloat = 2000
    let size = image.size
    let scale = min(1.0, maxEdge / max(size.width, size.height))
    let target = CGSize(width: size.width * scale, height: size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: target)
    let down = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    guard let data = down.jpegData(compressionQuality: 0.85) else { return down }
    return UIImage(data: data) ?? down
}


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
        imageURLs: .constant(["https://example.com/full.jpg"]),
        thumbURLs: .constant(["https://example.com/thumb.jpg"]),
        woId: "WO_PREVIEW",
        onImageTap: { url in
            print("TAPPED IMAGE URL: \(url)")
        },
        onAddNote: { _, _ in },
        onChangeStatus: { _, _ in }
    )


}
