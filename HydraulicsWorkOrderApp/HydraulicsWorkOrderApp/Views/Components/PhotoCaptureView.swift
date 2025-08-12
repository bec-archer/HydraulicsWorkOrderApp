//
//  PhotoCaptureView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/10/25.
//
//

import SwiftUI
import PhotosUI
import UIKit

// ───── PhotoCaptureView ─────
// Reusable image capture/picker for WO_Item(s).
// • Supports: Camera (single) + Photo Library (multi)
// • Returns: [UIImage] via @Binding for now — we'll swap to upload URLs once we wire Firebase Storage
// • Styling: Yellow-accented buttons to match Apple Notes vibe
@MainActor
struct PhotoCaptureView: View {
    
    // Parent binds to this; you'll map to WO_Item.imageUrls after uploads
    @Binding var images: [UIImage]

    // Optional inline QR button support
    var showQR: Bool = false
    var onScanQR: (() -> Void)? = nil

    
    // Presentation state (single source of truth avoids back‑to‑back sheet bugs)
    private enum ActiveSheet: Identifiable { case camera, library
        var id: String { self == .camera ? "camera" : "library" }
    }
    @State private var activeSheet: ActiveSheet?
    
    
    // Haptics are nice for technicians
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // ───── Header Row ─────
            HStack(spacing: 12) {
                // Camera
                Button {
                    haptic.impactOccurred()
                    activeSheet = .camera
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(hex: "#FFC500"))
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel("Take Photo with Camera")
                }

                // Photo Library
                Button {
                    activeSheet = .library
                } label: {
                    Text("Choose Photos")
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(hex: "#FFF8DC"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#E0E0E0"))
                        )
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel("Choose Photos from Library")
                }

                // ───── QR Code Scan (inline with capture buttons) ─────
                Spacer() // push QR button to the far right

                if showQR {
                    Button {
                        haptic.impactOccurred()
                        onScanQR?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan QR Code")
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.blue)             // 🔵 make it blue
                        .foregroundColor(.white)            // white text/icon for contrast
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                        .accessibilityLabel("Scan QR Code")
                    }
                    .buttonStyle(.plain)
                }
            } // END HStack (Header Row)

            .padding(.top, 4)

            
            // ───── Thumbnails Row (Horizontal) ─────
            ThumbnailsRow(images: $images)
                .padding(.vertical, 2)
            
        }
        // ───── Unified Sheet Presenter ─────
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .library:
                LibrarySheet(selectionLimit: 8) { newImages in
                    withAnimation { images.append(contentsOf: newImages) }
                    activeSheet = nil // Close sheet
                }
            case .camera:
                CameraSheet(onAdd: { img in
                    if let img { images.append(img) }
                    activeSheet = nil // Close sheet
                })
            }
        }
        // END .body
    }
    // END PhotoCaptureView
    
    // ───── LibrarySheet (isolates sheet content to calm the type-checker) ─────
    @MainActor
    private struct LibrarySheet: View {
        let selectionLimit: Int
        let onPicked: ([UIImage]) -> Void
        
        var body: some View {
            PhotoLibraryPicker(selectionLimit: selectionLimit, onPicked: onPicked)
                .ignoresSafeArea()
        }
        // END .body
    }
    
    // ───── PhotoLibraryPicker (UIKit PHPicker bridge) ─────
    @MainActor
    private struct PhotoLibraryPicker: UIViewControllerRepresentable {
        var selectionLimit: Int = 8
        var onPicked: ([UIImage]) -> Void
        
        func makeUIViewController(context: Context) -> PHPickerViewController {
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.filter = .images
            config.selectionLimit = selectionLimit
            
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }
        
        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
        
        func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }
        
        final class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let onPicked: ([UIImage]) -> Void
            init(onPicked: @escaping ([UIImage]) -> Void) { self.onPicked = onPicked }
            
            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                guard !results.isEmpty else {
                    picker.dismiss(animated: true)
                    return
                }
                
                let group = DispatchGroup()
                var gathered: [UIImage] = []
                
                for result in results {
                    let provider = result.itemProvider
                    group.enter()
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let img = object as? UIImage {
                            gathered.append(img)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    self.onPicked(gathered)
                    picker.dismiss(animated: true)
                }
            }
        }
        
        // END
    }
    
    
    
    // ───── ThumbnailsRow (isolates enumerated ForEach to calm the type-checker) ─────
    @MainActor
    private struct ThumbnailsRow: View {
        @Binding var images: [UIImage]
        
        var body: some View {
            if images.isEmpty {
                // Subtle helper text when empty
                Text("Add at least one photo for this WO_Item.")
                    .font(.callout)
                    .foregroundColor(Color("#4A4A4A"))
                    .padding(.vertical, 2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // Use indices instead of tuple from enumerated() to simplify inference
                        // Take a snapshot of indices so SwiftUI diffing has stable identity
                        let snap = Array(images.indices)
                        ForEach(snap, id: \.self) { index in
                            ThumbnailCell(
                                image: images[index],
                                onRemove: {
                                    // Hop to next runloop tick so SwiftUI's diffing isn't mid‑flight
                                    DispatchQueue.main.async {
                                        guard images.indices.contains(index) else { return }
                                        _ = withAnimation { images.remove(at: index) }
                                    }
                                }
                                
                            )
                        }
                        
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        // END .body
    }
    // ───── ThumbnailCell (single image tile with remove button) ─────
    @MainActor
    private struct ThumbnailCell: View {
        let image: UIImage
        let onRemove: () -> Void
        
        var body: some View {
            ZStack(alignment: .topTrailing) {
                // Photo tile
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("#E0E0E0"))
                    )
                
                // Small 'X' remove button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .background(
                            Circle().fill(Color(hex: "#FFC500"))   // yellow accent
                        )
                }
                .offset(x: 6, y: -6)
                .accessibilityLabel("Remove photo")
            }
            // END .body
        }
    }
    
    // ───── CameraSheet (isolates sheet content to calm the type-checker) ─────
    @MainActor
    private struct CameraSheet: View {
        let onAdd: (UIImage?) -> Void
        
        var body: some View {
            CameraCaptureView(onCapture: onAdd)
                .ignoresSafeArea()
        }
        // END .body
    }
    
    // ───── CameraCaptureView (UIKit bridge) ─────
    // Minimal UIImagePickerController wrapper for camera capture.
    // If camera is unavailable (simulator), gracefully dismisses.
    @MainActor
    struct CameraCaptureView: UIViewControllerRepresentable {
        
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
                let image = info[.originalImage] as? UIImage
                onCapture(image)
                picker.dismiss(animated: true)
            }
            
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                onCapture(nil)
                picker.dismiss(animated: true)
            }
        }
        // END
    }
}

// ───── Color Hex Helper ─────
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    // Convenience so existing calls like Color("#FFC500") still compile
    init(_ hex: String) { self.init(hex: hex) }
}

// ───── PhotoCaptureUploadView (uploads to Firebase, returns URLs) ─────
// Drop‑in wrapper that uses PhotoCaptureView for UI, but automatically
// uploads each newly added image to Firebase Storage and appends the
// resulting URLs to the provided bindings.
//
// • Keeps your existing PhotoCaptureView(images:) unchanged
// • Sequentially uploads new photos to avoid concurrency spikes
// • Shows a small progress indicator while uploading
// • Collects errors (non-blocking) so techs can keep working
@MainActor
struct PhotoCaptureUploadView: View {
    
    // ───── Bindings to your model ─────
    // Recommended: bind these to WO_Item.imageUrls and WO_Item.thumbUrls
    @Binding var imageURLs: [String]
    @Binding var thumbURLs: [String]

    // WorkOrder context for Storage pathing
    let woId: String
    let woItemId: UUID

    // Inline QR support (passed down to PhotoCaptureView)
    var showQR: Bool = false
    var onScanQR: (() -> Void)? = nil

    
    // Local scratchpad for captured images (not persisted)
    @State private var localImages: [UIImage] = []
    
    // Upload state
    @State private var uploadedCount: Int = 0            // how many localImages already uploaded
    @State private var isUploading: Bool = false
    @State private var uploadErrors: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            // Reuse your existing capture/picker UI (now with inline QR)
            PhotoCaptureView(images: $localImages, showQR: showQR, onScanQR: onScanQR)

            
            // Subtle progress
            if isUploading {
                ProgressView("Uploading photos…")
                    .progressViewStyle(.linear)
                    .padding(.vertical, 4)
            }
            
            // Non-blocking error note (dev-visible)
            if !uploadErrors.isEmpty {
                Text("Some uploads failed (\(uploadErrors.count)).")
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
        // ───── Auto-upload newly appended images ─────
        .onChange(of: localImages) { _, newImages in
            // Only act when new images were appended
            guard newImages.count > uploadedCount else { return }
            
            let toUpload = Array(newImages.dropFirst(uploadedCount)) // only the new ones
            isUploading = true
            
            Task {
                for img in toUpload {
                    do {
                        // 🔧 Ensure image is < 5 MB per Storage rules before uploading
                        let prepared = compressForFirebase(img)

                        let (fullURL, thumbURL) = try await StorageManager.shared
                            .uploadWOItemImageWithThumbnail(prepared, woId: woId, woItemId: woItemId)
                        
                        // Hop to main to update bindings
                        await MainActor.run {
                            imageURLs.append(fullURL)
                            thumbURLs.append(thumbURL)
                            uploadedCount += 1
                        }
                    } catch {
                        await MainActor.run {
                            uploadErrors.append(error.localizedDescription)
                            uploadedCount += 1   // mark as processed to avoid re-looping
                        }
                    }
                }
                
                await MainActor.run { isUploading = false }
            }

        }
        // END .body
    }
    // ───── Image Compressor (< 5 MB for Firebase Storage rules) ─────
    private func compressForFirebase(_ image: UIImage) -> UIImage {
        // Downscale longest edge to ~2000 px to shrink big photos
        let maxEdge: CGFloat = 2000
        let size = image.size
        let scale = min(1.0, maxEdge / max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let downscaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // Step down JPEG quality until we're safely under 5 MB
        var quality: CGFloat = 0.85
        var data = downscaled.jpegData(compressionQuality: quality) ?? image.jpegData(compressionQuality: 0.8)!
        let maxBytes = 4_800_000  // keep headroom under 5 MB rule

        while data.count > maxBytes && quality > 0.4 {
            quality -= 0.1
            if let d = downscaled.jpegData(compressionQuality: quality) {
                data = d
            } else {
                break
            }
        }

        // Recreate UIImage from final data to keep existing API (UIImage) unchanged
        return UIImage(data: data) ?? downscaled
    }
    // END

    // END PhotoCaptureUploadView
}



// ───── Preview Templates ─────
#Preview("PhotoCaptureView – Demo") {
    PhotoCaptureView(images: .constant([]))
}
#Preview("PhotoCaptureUploadView – Demo (no upload)") {
    // NOTE: This preview does not actually call Firebase.
    // It just shows layout with dummy bindings.
    PhotoCaptureUploadView(
        imageURLs: .constant([]),
        thumbURLs: .constant([]),
        woId: "WO_PREVIEW",
        woItemId: UUID()
    )
        .padding()
}
// END FILE
