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
    @State private var showImageViewer = false
    @State private var selectedImageURL: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ───── Header Section ─────
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
                                    .accessibilityLabel(Text(verbatim: color + " color swatch"))
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
            let thumbURLs = item.thumbUrls
            let fullURLs = item.imageUrls

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(fullURLs.enumerated()), id: \.offset) { index, fullURL in
                        let thumbURL = thumbURLs.indices.contains(index) ? thumbURLs[index] : fullURL

                        if let thumb = URL(string: thumbURL),
                           let full = URL(string: fullURL) {

                            AsyncImage(url: thumb) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 120, height: 120)

                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipped()
                                        .cornerRadius(10)
                                        .onTapGesture {
                                            print("🖼 Thumbnail tapped: \(full.absoluteString)")
                                            selectedImageURL = full
                                            showImageViewer = true
                                        }

                                case .failure:
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.red.opacity(0.2))
                                        .frame(width: 120, height: 120)

                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
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
                            ForEach(0..<selectedImages.count, id: \.self) { index in
                                Image(uiImage: selectedImages[index])
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
            // Fix for deprecated onChange API
            .onChange(of: photoItems) { _, newItems in
                loadSelectedImages(from: newItems)
            }
        } // END VStack
        .onAppear {
            print("🧪 ItemCard loaded for item \(item.id)")
            print("📷 imageUrls:", item.imageUrls)
            print("📷 thumbUrls:", item.thumbUrls)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .fullScreenCover(isPresented: $showImageViewer) {
            if let url = selectedImageURL {
                ImageViewer(imageURL: url, isPresented: $showImageViewer)
            }
        }
    } // END .body
    
    // ───── Load Images from PhotosPicker ─────
    private func loadSelectedImages(from items: [PhotosPickerItem]) {
        selectedImages.removeAll()

        for item in items {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        selectedImages.append(image)
                    }
                } else {
                    print("❌ Failed to load image from PhotosPickerItem")
                }
            }
        }
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
    }

    // ───── Image Upload Handler ─────
    func uploadImagesAndCreateNote(for item: WO_Item) {
        guard !noteText.isEmpty || !selectedImages.isEmpty else { return }

        let user = appState.currentUserName.isEmpty ? "Tech" : appState.currentUserName
        let ts = Date()
        let noteId = UUID()
        var uploadedURLs: [String] = []

        let group = DispatchGroup()

        for (index, image) in selectedImages.enumerated() {
            group.enter()

            guard let data = image.jpegData(compressionQuality: 0.7) else {
                group.leave()
                continue
            }

            let path = "intake/\(item.id.uuidString)/note_\(noteId)_\(index).jpg"
            let ref = Storage.storage().reference().child(path)

            ref.putData(data, metadata: StorageMetadata()) { _, err in
                if let error = err {
                    print("❌ Image upload error: \(error.localizedDescription)")
                    group.leave()
                    return
                }

                ref.downloadURL { url, _ in
                    if let url = url {
                        uploadedURLs.append(url.absoluteString)
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            let noteTextWithImages = uploadedURLs.isEmpty
                ? noteText
                : noteText + "\n\nAttached Images:\n" + uploadedURLs.joined(separator: "\n")

            let note = WO_Note(
                id: noteId,
                user: user,
                text: noteTextWithImages,
                timestamp: ts
            )

            onAddNote(item, note)
            noteText = ""
            selectedImages.removeAll()
        }
    }
}

// ───── Image Viewer Component ─────
struct ImageViewer: View {
    let imageURL: URL
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            if scale > 1 {
                                withAnimation {
                                    scale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            } else {
                                withAnimation {
                                    scale = 2
                                }
                            }
                        }
                case .failure:
                    Text("Failed to load image")
                        .foregroundColor(.white)
                @unknown default:
                    EmptyView()
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}
