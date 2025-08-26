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
    
    // Optional: existing image URLs to display alongside local images
    var existingImageURLs: [String] = []

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
            ThumbnailsRow(images: $images, existingImageURLs: existingImageURLs)
                .padding(.vertical, 2)
            
        }
                // Keep the sticky controls out of keyboard accessory layout + hide accessory bar (iOS 16+)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                // ───── Unified Sheet Presenter ─────
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .library:
                        LibrarySheet(selectionLimit: 8, onPicked: { (newImages: [UIImage]) in
                            withAnimation { images.append(contentsOf: newImages) }
                            activeSheet = nil // Close sheet
                        })
                    case .camera:
                        CameraSheet(onAdd: { (img: UIImage?) in
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
        var existingImageURLs: [String] = []
        
        var body: some View {
            let totalImageCount = images.count + existingImageURLs.count
            
            if totalImageCount == 0 {
                // Subtle helper text when empty
                Text("Add at least one photo for this WO_Item.")
                    .font(.callout)
                    .foregroundColor(Color("#4A4A4A"))
                    .padding(.vertical, 2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // Display existing URL-based images first
                        ForEach(Array(existingImageURLs.enumerated()), id: \.offset) { index, urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 92, height: 92)
                                            .background(Color.gray.opacity(0.2))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 92, height: 92)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color("#E0E0E0"))
                                            )
                                    case .failure:
                                        Color.gray
                                            .frame(width: 92, height: 92)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .overlay(
                                    // Remove button for existing images
                                    Button(action: {
                                        // Note: This would need to be handled by the parent
                                        // For now, we'll just show the button but not implement removal
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.black)
                                            .background(
                                                Circle().fill(Color(hex: "#FFC500"))
                                            )
                                    }
                                    .offset(x: 6, y: -6)
                                    .accessibilityLabel("Remove photo"),
                                    alignment: .topTrailing
                                )
                            }
                        }
                        
                        // Display local UIImage objects
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
    
    // Track if we've initialized localImages from existing URLs
    @State private var hasInitializedFromURLs: Bool = false
    
    // Upload state
    @State private var uploadedCount: Int = 0            // how many localImages already uploaded
    @State private var isUploading: Bool = false
    @State private var uploadErrors: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            // Reuse your existing capture/picker UI (now with inline QR)
            PhotoCaptureView(images: $localImages, existingImageURLs: imageURLs, showQR: showQR, onScanQR: onScanQR)

            
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
        // ───── Initialize localImages from existing URLs ─────
        .onAppear {
            if !hasInitializedFromURLs && !imageURLs.isEmpty {
                // Initialize localImages with existing images to prevent them from disappearing
                // when the view is recreated (e.g., after collapse/expand)
                hasInitializedFromURLs = true
                // We don't need to actually load the images into localImages since they're already
                // in imageURLs and thumbURLs, but we need to mark that we've seen them
                uploadedCount = imageURLs.count
            }
        }
        // ───── Prevent localImages from being reset on view refresh ─────
        .onChange(of: imageURLs) { _, newURLs in
            // If localImages is empty but we have URLs, it means the view was refreshed
            // and we need to prevent the upload process from running
            if localImages.isEmpty && !newURLs.isEmpty && hasInitializedFromURLs {
                // Don't trigger upload - just sync the count
                uploadedCount = newURLs.count
            }
        }
        // ───── Sync with database cache to prevent duplication ─────
        .onChange(of: imageURLs.count) { _, newCount in
            // If the count increased unexpectedly, it might be from database sync
            // Check if we need to update our upload count to prevent re-uploading
            if newCount > uploadedCount && hasInitializedFromURLs {
                uploadedCount = newCount
            }
        }
        // ───── Auto-upload newly appended images ─────
        .onChange(of: localImages) { _, newImages in
            // Only act when new images were appended
            guard newImages.count > uploadedCount else { return }
            
            // Additional check: only proceed if we actually have new images to upload
            // This prevents the upload process from running when the view just refreshes
            let toUpload: [UIImage] = Array(newImages.dropFirst(uploadedCount)) // only the new ones
            guard !toUpload.isEmpty else { return }

            isUploading = true

            Task {
                // ── Collect results locally to avoid intermediate array length mismatches
                var pendingFull: [String] = []
                var pendingThumbs: [String] = []
                var pendingErrors: [String] = []

                for uiImage in toUpload {
                    do {
                        // 🔧 Ensure image is < 5 MB per Storage rules before uploading
                        let prepared = compressForFirebase(uiImage)

                        let (fullURL, thumbURL) = try await StorageManager.shared
                            .uploadWOItemImageWithThumbnail(prepared, woId: woId, woItemId: woItemId)

                        pendingFull.append(fullURL)
                        pendingThumbs.append(thumbURL)

                        // ───── Resolve Firestore docID from cache (fallback to passed woId) ─────
                        let resolvedDocId: String = {
                            // First try to find by item ID in any work order
                            if let foundWO = WorkOrdersDatabase.shared.workOrders.first(where: { wo in
                                wo.items.contains(where: { $0.id == woItemId })
                            }), let woId = foundWO.id, !woId.isEmpty {
                                return woId
                            }
                            // If not found by item, try to find by WO_Number (for newly created work orders)
                            // The woId parameter might be the WO_Number for newly created work orders
                            if let foundWO = WorkOrdersDatabase.shared.workOrders.first(where: { wo in
                                wo.WO_Number == woId
                            }), let woId = foundWO.id, !woId.isEmpty {
                                return woId
                            }
                            // If still not found, the work order might not be in the cache yet
                            // This can happen when images are uploaded before the work order is fully saved
                            // In this case, we'll let the retry mechanism handle it
                            return woId
                        }()

                        // ───── Also persist + publish to WorkOrdersDatabase so Active cards refresh now ─────
                        WorkOrdersDatabase.shared.applyItemImageURLs(
                            woId: resolvedDocId,
                            itemId: woItemId,
                            fullURL: fullURL,
                            thumbURL: thumbURL,
                            uploadedBy: "uploader"
                        ) { result in
                            if case let .failure(err as NSError) = result {
                                print("❌ applyItemImageURLs failed: \(err)")
                                // If we don't yet have a Firestore doc, the work order might not be saved yet
                                // The images are already uploaded to Firebase Storage, so they'll be available
                                // when the work order is saved. We'll retry the update later.
                                if err.domain == "WorkOrdersDatabase", err.code == 404 {
                                    // Schedule a retry for when the work order becomes available
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        WorkOrdersDatabase.shared.applyItemImageURLs(
                                            woId: resolvedDocId,
                                            itemId: woItemId,
                                            fullURL: fullURL,
                                            thumbURL: thumbURL,
                                            uploadedBy: "uploader"
                                        ) { _ in }
                                    }
                                }
                            }
                        }
                        // Ensure parent WorkOrder shows a preview immediately
                        WorkOrdersDatabase.shared.setWorkOrderPreviewIfEmpty(containingItem: woItemId, previewURL: thumbURL)
                        WorkOrdersDatabase.shared.scheduleWOPreviewPersistRetry(containingItem: woItemId, url: thumbURL, delay: 1.0)
                    } catch {
                        pendingErrors.append(error.localizedDescription)
                    }
                }

                // ── Update local arrays and handle errors
                await MainActor.run {
                    if !pendingFull.isEmpty {
                        // Update local arrays immediately for UI responsiveness
                        var newFull = imageURLs
                        var newThumb = thumbURLs
                        newFull.append(contentsOf: pendingFull)
                        newThumb.append(contentsOf: pendingThumbs)
                        
                        imageURLs = newFull
                        thumbURLs = newThumb
                        uploadedCount += pendingFull.count
                        
                        // Clear localImages after successful upload to prevent duplication
                        // This ensures ThumbnailsRow only shows images from existingImageURLs
                        localImages = []
                    }

                    if !pendingErrors.isEmpty {
                        uploadErrors.append(contentsOf: pendingErrors)
                        // We still bump uploadedCount to mark processed slots for images that failed
                        uploadedCount += pendingErrors.count
                    }

                    isUploading = false
                }
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

// ───── Availability-Safe: Hide Keyboard Toolbar (SDK-agnostic no-op) ─────
// NOTE: Some Xcode/iOS SDK combos don't expose `.keyboard` at compile time.
// To keep builds green everywhere, this modifier does nothing for now.
// If/when you move to an SDK that supports it, we can re-enable the call.
private struct KeyboardToolbarHidden: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        content
    }
}
// END



// ───── Compatibility Shims for WorkOrdersDatabase (DISABLED) ─────
// These temporary helpers are now superseded by real WorkOrdersDatabase APIs.
// We keep them wrapped (not deleted) for easy diff/recovery if needed.
#if false
#warning("Compatibility shims for WorkOrdersDatabase: remove if you implement these methods elsewhere")
// ───── Compatibility shims for WorkOrdersDatabase (UI-refresh fallbacks) ─────
@MainActor
extension WorkOrdersDatabase {
    /// Local-only update when Firestore doc isn’t ready yet. This mutates the in-memory
    /// cache (`workOrders`) so views like Active Work Orders can show thumbnails immediately.
    func applyItemImageURLsLocalOnly(itemId: UUID, fullURL: String, thumbURL: String) {
        // Find the WO containing this item
        guard let woIndex = workOrders.firstIndex(where: { wo in
            wo.items.contains(where: { $0.id == itemId })
        }) else {
            #if DEBUG
            print("ℹ️ LocalOnly: could not find WorkOrder containing item \(itemId)")
            #endif
            return
        }
        // Find the item index
        guard let itemIndex = workOrders[woIndex].items.firstIndex(where: { $0.id == itemId }) else { return }

        // Append URLs if not already present
        if !workOrders[woIndex].items[itemIndex].thumbUrls.contains(thumbURL) {
            workOrders[woIndex].items[itemIndex].thumbUrls.append(thumbURL)
        }
        if !workOrders[woIndex].items[itemIndex].imageUrls.contains(fullURL) {
            workOrders[woIndex].items[itemIndex].imageUrls.append(fullURL)
        }

        // Opportunistically set a top-level preview if your model has one
        // (older builds used `imageURL` or `imageURLs`). We avoid touching if absent.
        if let mirror = Mirror(reflecting: workOrders[woIndex]).children.first(where: { $0.label == "imageURL" }) {
            if var _ = mirror.value as? String? {
                // Best-effort via KVC-less copy on value types: reassign struct with updated property if it exists
                // If your model exposes a mutating setter, prefer that. Otherwise, rely on item thumbnails above.
            }
        }

        #if DEBUG
        print("✅ LocalOnly applied to item=\(itemIndex) in wo=\(workOrders[woIndex].id). thumbs=\(workOrders[woIndex].items[itemIndex].thumbUrls.count) images=\(workOrders[woIndex].items[itemIndex].imageUrls.count)")
        #endif

        // Since WorkOrdersDatabase is expected to be an ObservableObject with @Published workOrders,
        // this mutation should trigger a UI refresh automatically.
    }

    /// Schedules a local refresh soon after save; safe even if the doc already exists by then.
    func scheduleImageURLPersistRetry(woItemId: UUID, fullURL: String, thumbURL: String, delay: TimeInterval) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self.applyItemImageURLsLocalOnly(itemId: woItemId, fullURL: fullURL, thumbURL: thumbURL)
        }
    }
}

#warning("Compatibility shims for WorkOrdersDatabase: remove if you implement these methods elsewhere")
// ───── Additional compatibility helpers for WorkOrdersDatabase (WO preview) ─────
@MainActor
extension WorkOrdersDatabase {
    /// If the parent WO has no preview `imageURL`, set it to the given URL and bump `lastModified`.
    func setWorkOrderPreviewIfEmpty(woId: String, previewURL: String) {
        // WorkOrder.id is String in schema; match directly
        guard let woIndex = workOrders.firstIndex(where: { wo in
            (wo.id ?? "") == woId
        }) else {
            #if DEBUG
            print("ℹ️ setWorkOrderPreviewIfEmpty: WO not found for id \(woId)")
            #endif
            return
        }
        // Only set if empty / nil
        let current = workOrders[woIndex].imageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard current.isEmpty else { return }
        workOrders[woIndex].imageURL = previewURL
        workOrders[woIndex].lastModified = Date()
        // Nudge @Published by reassigning the element
        let updated = workOrders[woIndex]
        workOrders[woIndex] = updated
        #if DEBUG
        print("✅ Preview set locally for WO \(workOrders[woIndex].id): \(previewURL)")
        #endif
    }

    /// Schedule a retry to set the preview later (safe even if already set).
    func scheduleWOPreviewPersistRetry(woId: String, url: String, delay: TimeInterval) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self.setWorkOrderPreviewIfEmpty(woId: woId, previewURL: url)
        }
    }

    /// Variant that resolves the parent WorkOrder by walking items (avoids id type mismatches).
    func setWorkOrderPreviewIfEmpty(containingItem itemId: UUID, previewURL: String) {
        guard let woIndex = workOrders.firstIndex(where: { wo in
            wo.items.contains(where: { $0.id == itemId })
        }) else {
            #if DEBUG
            print("ℹ️ setWorkOrderPreviewIfEmpty(containingItem:): parent WO not found for item \(itemId)")
            #endif
            return
        }
        let current = workOrders[woIndex].imageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard current.isEmpty else { return }
        workOrders[woIndex].imageURL = previewURL
        workOrders[woIndex].lastModified = Date()
        let updated = workOrders[woIndex]
        workOrders[woIndex] = updated
        #if DEBUG
        print("✅ Preview set (via item) for WO \(workOrders[woIndex].WO_Number): \(previewURL)")
        #endif
    }

    /// Retry helper that uses item containment to find the parent WorkOrder later.
    func scheduleWOPreviewPersistRetry(containingItem itemId: UUID, url: String, delay: TimeInterval) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self.setWorkOrderPreviewIfEmpty(containingItem: itemId, previewURL: url)
        }
    }
}

#endif
// ───── END Compatibility Shims (Disabled) ─────

// ───── WorkOrdersDatabase Preview Helpers (Active, Non‑Shim) ─────
// These lightweight helpers are compiled (unlike the disabled shim block above).
// They only update the in‑memory cache so the UI can show a preview thumbnail ASAP.
// Persisting to Firestore should be handled by your primary DB methods elsewhere.
@MainActor
extension WorkOrdersDatabase {
    /// If the parent WorkOrder (resolved via item containment) has an empty preview,
    /// set it to the given URL and bump `lastModified`. No remote writes here.
    func setWorkOrderPreviewIfEmpty(containingItem itemId: UUID, previewURL: String) {
        guard let woIndex = workOrders.firstIndex(where: { wo in
            wo.items.contains(where: { $0.id == itemId })
        }) else {
            #if DEBUG
            print("ℹ️ setWorkOrderPreviewIfEmpty(containingItem:): parent WO not found for item \(itemId)")
            #endif
            return
        }
        let current = workOrders[woIndex].imageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard current.isEmpty else { return }
        workOrders[woIndex].imageURL = previewURL
        workOrders[woIndex].lastModified = Date()
        // Nudge @Published by reassigning the element
        let updated = workOrders[woIndex]
        workOrders[woIndex] = updated
        #if DEBUG
        print("✅ Preview set (via item) for WO \(workOrders[woIndex].WO_Number): \(previewURL)")
        #endif
    }

    /// Retry helper that resolves the parent WorkOrder by item containment and tries again later.
    func scheduleWOPreviewPersistRetry(containingItem itemId: UUID, url: String, delay: TimeInterval) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self.setWorkOrderPreviewIfEmpty(containingItem: itemId, previewURL: url)
        }
    }
}
// END Preview Helpers

// ───── Preview Templates ─────
#Preview("PhotoCaptureView – Demo") {
    PhotoCaptureView(images: .constant([]), existingImageURLs: [])
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
