//
//  ImageCaptureServiceView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 ImageCaptureServiceView.swift
// New image capture component using ImageManagementService for centralized image handling
// ─────────────────────────────────────────────────────────────

import SwiftUI
import PhotosUI
import UIKit

// MARK: - ImageCaptureServiceView
@MainActor
struct ImageCaptureServiceView: View {
    // MARK: - Properties
    @Binding var imageURLs: [String]
    @Binding var thumbURLs: [String]
    
    let itemId: UUID
    let onImagesChanged: (() -> Void)?
    
    // Optional QR support
    var showQR: Bool = false
    var onScanQR: (() -> Void)? = nil
    
    // MARK: - State
    @State private var localImages: [UIImage] = []
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedImages: [UIImage] = []
    
    // MARK: - Services
    private let imageService = ImageManagementService.shared
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack(spacing: 12) {
                // Camera Button
                Button {
                    haptic.impactOccurred()
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#FFC500"))
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel("Take Photo with Camera")
                }
                
                // Photo Library Button
                Button {
                    haptic.impactOccurred()
                    showImagePicker = true
                } label: {
                    Text("Choose Photos")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#FFF8DC"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#E0E0E0"))
                        )
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel("Choose Photos from Library")
                }
                
                Spacer()
                
                // QR Code Button
                if showQR {
                    Button {
                        haptic.impactOccurred()
                        onScanQR?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan QR Code")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                        .accessibilityLabel("Scan QR Code")
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Progress Indicator
            if isUploading {
                VStack(spacing: 4) {
                    ProgressView(value: uploadProgress, total: 1.0)
                        .progressViewStyle(.linear)
                    Text("Uploading images...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // Existing Images Display
            if !imageURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
                            if let url = URL(string: urlString) {
                                Button {
                                    // TODO: Show full screen image viewer
                                } label: {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 80, height: 80)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        case .failure:
                                            Color.gray
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        @unknown default:
                                            Color.gray
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            await deleteImage(urlString)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                if let image = image {
                    selectedImages = [image]
                    Task {
                        await uploadImages(selectedImages)
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoLibraryPicker { images in
                selectedImages = images
                Task {
                    await uploadImages(selectedImages)
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func uploadImages(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        
        isUploading = true
        uploadProgress = 0.0
        
        do {
            // Upload images using the service
            let uploadedURLs = try await imageService.uploadImages(images, for: itemId)
            
            // Update the bindings
            imageURLs.append(contentsOf: uploadedURLs)
            
            // Get updated thumbnail URLs
            let thumbnailURLs = try await imageService.getThumbnailURLs(for: itemId)
            thumbURLs = thumbnailURLs
            
            // Notify parent
            onImagesChanged?()
            
            uploadProgress = 1.0
            
        } catch {
            print("❌ Failed to upload images: \(error.localizedDescription)")
        }
        
        isUploading = false
        selectedImages = []
    }
    
    private func deleteImage(_ imageURL: String) async {
        do {
            try await imageService.deleteImage(imageURL)
            
            // Remove from local arrays
            imageURLs.removeAll { $0 == imageURL }
            
            // Get updated thumbnail URLs
            let thumbnailURLs = try await imageService.getThumbnailURLs(for: itemId)
            thumbURLs = thumbnailURLs
            
            // Notify parent
            onImagesChanged?()
            
        } catch {
            print("❌ Failed to delete image: \(error.localizedDescription)")
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage?) -> Void
        
        init(onImageCaptured: @escaping (UIImage?) -> Void) {
            self.onImageCaptured = onImageCaptured
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            onImageCaptured(image)
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageCaptured(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Photo Library Picker
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onImagesSelected: ([UIImage]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // No limit
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagesSelected: onImagesSelected)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagesSelected: ([UIImage]) -> Void
        
        init(onImagesSelected: @escaping ([UIImage]) -> Void) {
            self.onImagesSelected = onImagesSelected
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                onImagesSelected([])
                picker.dismiss(animated: true)
                return
            }
            
            let group = DispatchGroup()
            var gathered: [UIImage?] = Array(repeating: nil, count: results.count)
            
            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let img = object as? UIImage {
                        gathered[index] = img
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                let finalImages = gathered.compactMap { $0 }
                self.onImagesSelected(finalImages)
                picker.dismiss(animated: true)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ImageCaptureServiceView(
        imageURLs: .constant([]),
        thumbURLs: .constant([]),
        itemId: UUID(),
        onImagesChanged: nil
    )
}
