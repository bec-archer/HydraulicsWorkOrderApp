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
        Text("Photo Capture Placeholder")
    }
    // END PhotoCaptureView
    
    // ───── LibrarySheet (isolates sheet content to calm the type-checker) ─────
    @MainActor
    private struct LibrarySheet: View {
        let selectionLimit: Int
        let onPicked: ([UIImage]) -> Void
        
        var body: some View {
            Text("Library Sheet Placeholder")
        }
        // END .body
    }
    
    // ───── PhotoLibraryPicker (UIKit PHPicker bridge) ─────
    private struct PhotoLibraryPicker: UIViewControllerRepresentable {
        let selectionLimit: Int
        let onPicked: ([UIImage]) -> Void
        
        func makeUIViewController(context: Context) -> PHPickerViewController {
            var config = PHPickerConfiguration()
            config.selectionLimit = selectionLimit
            config.filter = .images
            
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }
        
        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let parent: PhotoLibraryPicker
            
            init(_ parent: PhotoLibraryPicker) {
                self.parent = parent
            }
            
            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                picker.dismiss(animated: true)
                
                guard !results.isEmpty else { return }
                
                var images: [UIImage] = []
                let group = DispatchGroup()
                
                for result in results {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        defer { group.leave() }
                        if let image = object as? UIImage {
                            DispatchQueue.main.async {
                                images.append(image)
                            }
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    self.parent.onPicked(images)
                }
            }
        }
    }
    
    // ───── ThumbnailsRow (horizontal scroll of image thumbnails) ─────
    private struct ThumbnailsRow: View {
        @Binding var images: [UIImage]
        let existingImageURLs: [String]
        
        var body: some View {
            Text("Thumbnails Row Placeholder")
        }
        // END .body
    }
    // ───── ThumbnailCell (single image tile with remove button) ─────
    @MainActor
    private struct ThumbnailCell: View {
        let image: UIImage
        let onRemove: () -> Void
        
        var body: some View {
            Text("Thumbnail Cell Placeholder")
        }
        
        // END .body
    }
    
    // ───── CameraSheet (isolates sheet content to calm the type-checker) ─────
    @MainActor
    private struct CameraSheet: View {
        let onAdd: (UIImage?) -> Void
        
        var body: some View {
            Text("Camera Sheet Placeholder")
        }
        // END .body
    }
    
    // ───── CameraCaptureView (UIKit bridge) ─────
    struct CameraCaptureView: UIViewControllerRepresentable {
        let onAdd: (UIImage?) -> Void
        
        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = context.coordinator
            return picker
        }
        
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
            let parent: CameraCaptureView
            
            init(_ parent: CameraCaptureView) {
                self.parent = parent
            }
            
            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                if let image = info[.originalImage] as? UIImage {
                    parent.onAdd(image)
                } else {
                    parent.onAdd(nil)
                }
            }
            
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                parent.onAdd(nil)
            }
        }
    }
}

// ───── Color Hex Helper ─────
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255)
    }

    // Convenience so existing calls like Color("#FFC500") still compile
    init(_ hex: String) { self.init(hex: hex) }
}

// ───── PhotoCaptureUploadView (uploads to Firebase, returns URLs) ─────
@MainActor
struct PhotoCaptureUploadView: View {
    // Parent binds to this; you'll map to WO_Item.imageUrls after uploads
    @Binding var localImages: [UIImage]
    
    // Existing image URLs to display alongside local images
    var imageURLs: [String] = []
    
    // Work order context for uploads
    var woId: String = ""
    var woItemId: String = ""
    
    // Callback when images change
    var onImagesChanged: (() -> Void)? = nil
    
    // State tracking
    @State private var hasInitializedFromURLs: Bool = false
    @State private var uploadedCount: Int = 0            // how many localImages already uploaded
    @State private var isUploading: Bool = false
    @State private var uploadErrors: [String] = []
    
    var body: some View {
        Text("Photo Capture Upload Placeholder")
    }
    
    // END PhotoCaptureUploadView
}

// ───── Availability-Safe: Hide Keyboard Toolbar (SDK-agnostic no-op) ─────
// NOTE: Some Xcode/iOS SDK combos don't expose `.keyboard` at compile time.
// To keep builds green everywhere, this modifier does nothing for now.
private struct KeyboardToolbarHidden: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
// END

#Preview("PhotoCaptureView – Demo") {
    PhotoCaptureView(images: .constant([]), existingImageURLs: [])
}
#Preview("PhotoCaptureUploadView – Demo (no upload)") {
    // NOTE: This preview does not actually call Firebase.
    PhotoCaptureUploadView(
        localImages: .constant([]),
        imageURLs: [],
        woId: "preview-wo",
        woItemId: "preview-item"
    )
        .padding()
}
// END FILE