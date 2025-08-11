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
            }

            
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

// ───── Preview Template ─────
#Preview("PhotoCaptureView – Demo") {
    PhotoCaptureView(images: .constant([]))
}
// END FILE
