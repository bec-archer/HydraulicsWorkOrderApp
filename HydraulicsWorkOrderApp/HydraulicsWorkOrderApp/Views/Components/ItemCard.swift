//  ItemCard.swift
//  HydraulicsWorkOrderApp

import SwiftUI
import FirebaseStorage
import PhotosUI

// ───── ItemCard View ─────

struct ItemCard: View {
    let item: WO_Item
    var onAddNote: (WO_Item, WO_Note) -> Void
    var onChangeStatus: (WO_Item, String) -> Void

    @EnvironmentObject var appState: AppState
    @State private var noteText: String = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []

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

            // ───── Add Note + Images ─────
            VStack(alignment: .leading, spacing: 6) {
                Text("+ Add Note")
                    .font(.subheadline.bold())

                TextEditor(text: $noteText)
                    .frame(height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))

                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedImages, id: \.self) { image in
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipped()
                                    .cornerRadius(6)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button("Add Images") {
                        showPhotoPicker = true
                    }
                    .buttonStyle(.bordered)

                    Button("Save Note") {
                        uploadImagesAndCreateNote(for: item)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#FFC500"))
                }
            }
            .padding(.top, 8)
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $photoItems,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: photoItems) { newItems in
                for item in newItems {
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImages.append(image)
                        } else {
                            print("❌ Failed to load image from PhotosPickerItem")
                        }
                    }
                }
            }
        } // END VStack
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    } // END .body

    // ───── Status-Based Color Mapping ─────
    func statusColor(for status: String?) -> Color {
        switch status?.lowercased() {
        case "checked in":   return UIConstants.StatusColors.checkedIn
        case "disassembly":  return UIConstants.StatusColors.disassembly
        case "in progress":  return UIConstants.StatusColors.inProgress
        case "test failed":  return UIConstants.StatusColors.testFailed
        case "completed":    return UIConstants.StatusColors.completed
        case "closed":       return UIConstants.StatusColors.closed
        default:              return UIConstants.StatusColors.fallback
        }
    } // END

    // ───── Image Upload Handler ─────
    func uploadImagesAndCreateNote(for item: WO_Item) {
        guard !noteText.isEmpty || !selectedImages.isEmpty else { return }

        let user = appState.currentUserName.isEmpty ? "Tech" : appState.currentUserName
        let ts = Date()
        let noteId = UUID()
        var uploadedURLs: [String] = []

        let group = DispatchGroup()

        print("🖼 selectedImages count: \(selectedImages.count)")
        for image in selectedImages {
            group.enter()

            guard let data = image.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to convert UIImage to JPEG")
                group.leave()
                continue
            }

            let path = "intake/\(item.id.uuidString)/note_\(noteId).jpg"
            let ref = Storage.storage().reference().child(path)

            ref.putData(data, metadata: StorageMetadata()) { _, err in
                if let err = err {
                    print("❌ Upload failed: \(err.localizedDescription)")
                    group.leave()
                    return
                }
                ref.downloadURL { url, _ in
                print("🌐 Download URL received: \(url?.absoluteString ?? "nil")")
                    if let url = url {
                        uploadedURLs.append(url.absoluteString)
                    }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            print("📸 Uploaded image URLs: \(uploadedURLs)") // ← add this line

            let note = WO_Note(
                id: noteId,
                user: user,
                text: noteText,
                timestamp: ts,
                imageURLs: uploadedURLs
            )

            onAddNote(item, note)
            noteText = ""
            selectedImages.removeAll()
        }

    } // END uploadImagesAndCreateNote

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
