//  ItemCard.swift
//  HydraulicsWorkOrderApp
import SwiftUI
import PhotosUI
import UIKit

// ───── Image URL Resolver (thumb ↔ full, zipped) ─────
// Keeps thumbnail and full-size arrays paired to prevent mismatches.
// Uses zip so UI never indexes past bounds even if one array lags temporarily.
private func resolvedURL(for item: WO_Item, at index: Int) -> URL? {
    let pairs = Array(zip(item.thumbUrls, item.imageUrls))
    
    // Preferred: use zipped pair at index
    if pairs.indices.contains(index) {
        let (_, full) = pairs[index]
        if let url = URL(string: full), !full.isEmpty {
            print("🖼️ tapped(full paired): \(full)")
            return url
        }
    }
    
    // Fallbacks: first valid full, then first valid thumb
    if let firstFull = item.imageUrls.first, let url = URL(string: firstFull), !firstFull.isEmpty {
        print("🖼️ tapped(fallback full first): \(firstFull)")
        return url
    }
    if let firstThumb = item.thumbUrls.first, let url = URL(string: firstThumb), !firstThumb.isEmpty {
        print("🖼️ tapped(fallback thumb first): \(firstThumb)")
        return url
    }
    
    print("🖼️ tapped: no valid URL for item \(item.id)")
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
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showCamera = false


    let statusOptions: [String] = [
        "Checked In",
        "Disassembly",
        "In Progress",
        "Test Failed",
        "Completed",
        "Closed"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ───── Item Type + Status Row ─────
            HStack(alignment: .center, spacing: 12) {
                Text(item.type)
                    .font(.headline)
                
                Spacer()
                
                // Color-coded capsule showing current status
                let currentStatus = item.statusHistory.last?.status ?? "Checked In"
                Text(currentStatus)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(statusColor(for: currentStatus).opacity(0.15))
                    .foregroundColor(statusColor(for: currentStatus))
                    .clipShape(Capsule())
            }
            
            // ───── Images Row ─────
            // Multiple images in horizontal scroll
            if !item.thumbUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Use paired thumb/full URLs, fallback to individual arrays
                        let paired = Array(zip(item.thumbUrls, item.imageUrls))
                        if !paired.isEmpty {
                                                            ForEach(Array(paired.enumerated()), id: \.offset) { index, pair in
                                    let (thumb, _) = pair
                                if let thumbURL = URL(string: thumb) {
                                    Button {
                                        if let url = resolvedURL(for: item, at: index) {
                                            onImageTap?(url)
                                        } else {
                                            print("❌ No resolvable URL for item \(item.id) at index \(index)")
                                        }
                                    } label: {
                                        AsyncImage(url: thumbURL) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView().frame(width: 200, height: 200)
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
                        } else {
                            // Fallback: use thumbUrls if available
                            ForEach(Array(item.thumbUrls.enumerated()), id: \.offset) { index, thumb in
                                if let thumbURL = URL(string: thumb) {
                                    Button {
                                        if let url = resolvedURL(for: item, at: index) {
                                            onImageTap?(url)
                                        }
                                    } label: {
                                        AsyncImage(url: thumbURL) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView().frame(width: 200, height: 200)
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
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                // No images placeholder
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 200, height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            // END Images

            // ───── Status Change Picker ─────
            if let onChangeStatus = onChangeStatus {
                // Keep selection valid and in sync with history
                let current = item.statusHistory.last?.status ?? "Checked In"

                Picker("Update Status", selection: $selectedStatus) {
                    ForEach(statusOptions, id: \.self) { status in
                        Text(status).tag(status)
                    }
                }
                .pickerStyle(.menu)
                .onAppear {
                    // Initialize selection so the menu has a valid tag
                    if selectedStatus.isEmpty { selectedStatus = current }
                }
                .onChange(of: item.statusHistory.last?.status) { _, latest in
                    // Refresh selection when history changes (e.g., after save)
                    selectedStatus = latest ?? "Checked In"
                }
                .onChange(of: selectedStatus) { _, newStatus in
                    guard !newStatus.isEmpty, newStatus != current else { return }
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

                            // Inline image picker (staged locally; upload happens on Save)
                            PhotosPicker(
                                selection: $photoItems,
                                maxSelectionCount: 8,
                                matching: .images
                            ) {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Add Photos")
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Color(hex: "#FFF8DC"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#E0E0E0"))
                                )
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .accessibilityLabel("Add Photos to Note")
                            }
                            .onChange(of: photoItems) { _, newItems in
                                guard !newItems.isEmpty else { return }
                                Task {
                                    for item in newItems {
                                        if let data = try? await item.loadTransferable(type: Data.self),
                                           let ui = UIImage(data: data) {
                                            stagedImages.append(ui)
                                        }
                                    }
                                    // Clear the picker items so subsequent selections trigger again
                                    photoItems.removeAll()
                                }
                            }
                            
                            // Preview staged images (kept local until Save)
                            if !stagedImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(stagedImages.enumerated()), id: \.offset) { _, img in
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 72, height: 72)
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(Color.gray.opacity(0.2))
                                                )
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }

                            // Inline camera capture (staged locally; upload happens on Save)
                            Button {
                                showCamera = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                    Text("Take Photo")
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Color(hex: "#FFC500"))
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .accessibilityLabel("Take Photo for Note")
                            }
                            .buttonStyle(.plain)

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
                    }
                    .fullScreenCover(isPresented: $showCamera) {
                        NoteCameraCaptureView { captured in
                            if let captured {
                                stagedImages.append(captured)
                            }
                            showCamera = false
                        }
                        .ignoresSafeArea()
                    }
                    .interactiveDismissDisabled(
                        isSavingNote ||
                        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        !stagedImages.isEmpty
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingAddNote = false }
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

// ───── Status Color Helper ─────
private func statusColor(for status: String) -> Color {
    switch status.lowercased() {
    case "checked in":       return UIConstants.StatusColors.checkedIn
    case "disassembly":      return UIConstants.StatusColors.disassembly
    case "in progress":      return UIConstants.StatusColors.inProgress
    case "test failed":      return UIConstants.StatusColors.testFailed
    case "completed":        return UIConstants.StatusColors.completed
    case "closed":           return UIConstants.StatusColors.closed
    case "done":             return UIConstants.StatusColors.completed
    case "tested: pass":     return UIConstants.StatusColors.completed
    case "tested: fail":     return UIConstants.StatusColors.testFailed
    default:                 return UIConstants.StatusColors.fallback
    }
}
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

// ───── Camera bridge for note modal (no nested sheets) ─────
private struct NoteCameraCaptureView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIImagePickerController

    var onCapture: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let img = info[.originalImage] as? UIImage
            onCapture(img)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
            picker.dismiss(animated: true)
        }
    }
}

// ───── PREVIEW TEMPLATE ─────
#Preview {
    let statusHistory: [WO_Status] = [
        WO_Status(status: "Checked In", user: "Maria", timestamp: Date(), notes: nil)
    ]

    let sampleItem = WO_Item(
        id: UUID(),
        woItemId: "250826-001-WOI-001",
        tagId: "ABC123",
        imageUrls: ["https://example.com/full.jpg"],
        thumbUrls: ["https://example.com/thumb.jpg"],
        type: "Cylinder",
        dropdowns: [:],
        dropdownSchemaVersion: 1,
        reasonsForService: [],
        reasonNotes: nil,
        completedReasons: [],
        statusHistory: statusHistory,
        testResult: nil,
        partsUsed: nil,
        hoursWorked: nil,
        cost: nil,
        assignedTo: "Tech",
        isFlagged: false,
        tagReplacementHistory: nil
    )

    ItemCard(
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
