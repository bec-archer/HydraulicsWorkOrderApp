import SwiftUI
import FirebaseStorage
import Combine



@MainActor
class ImageManagementService: ObservableObject {
    // MARK: - Singleton
    static let shared = ImageManagementService()
    
    // MARK: - Published Properties
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Private Properties
    private let storage = Storage.storage()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Upload a single image and return the URL
    func uploadImage(_ image: UIImage, for workOrderId: String, itemId: UUID) async throws -> String {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        defer {
            isUploading = false
            uploadProgress = 0.0
        }
        
        do {
            // Compress image
            guard let compressedImageData = image.jpegData(compressionQuality: 0.8) else {
                throw ImageError.compressionFailed
            }
            
            // Create thumbnail
            let thumbnailImage = image.resized(to: CGSize(width: 200, height: 200))
            guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.6) else {
                throw ImageError.thumbnailCreationFailed
            }
            
            // Generate unique filename
            let filename = "\(UUID().uuidString).jpg"
            let imagePath = "workOrders/\(workOrderId)/items/\(itemId)/images/\(filename)"
            let thumbnailPath = "workOrders/\(workOrderId)/items/\(itemId)/thumbnails/\(filename)"
            
            // Upload main image
            let imageRef = storage.reference().child(imagePath)
            let imageMetadata = StorageMetadata()
            imageMetadata.contentType = "image/jpeg"
            
            let imageUploadTask = imageRef.putData(compressedImageData, metadata: imageMetadata)
            
            // Upload thumbnail
            let thumbnailRef = storage.reference().child(thumbnailPath)
            let thumbnailMetadata = StorageMetadata()
            thumbnailMetadata.contentType = "image/jpeg"
            
            let thumbnailUploadTask = thumbnailRef.putData(thumbnailData, metadata: thumbnailMetadata)
            
            // Monitor progress
            imageUploadTask.observe(.progress) { snapshot in
                let progress = Double(snapshot.progress!.completedUnitCount) / Double(snapshot.progress!.totalUnitCount)
                self.uploadProgress = progress
            }
            
            // Wait for both uploads to complete
            let (imageResult, thumbnailResult) = try await (
                imageUploadTask.value,
                thumbnailUploadTask.value
            )
            
            // Get download URLs
            let imageURL = try await imageRef.downloadURL().absoluteString
            let thumbnailURL = try await thumbnailRef.downloadURL().absoluteString
            
            return imageURL
            
        } catch {
            setError("Failed to upload image: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Upload multiple images and return URLs
    func uploadImages(_ images: [UIImage], for workOrderId: String, itemId: UUID) async throws -> [String] {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        defer {
            isUploading = false
            uploadProgress = 0.0
        }
        
        var uploadedURLs: [String] = []
        let totalImages = images.count
        
        for (index, image) in images.enumerated() {
            do {
                let imageURL = try await uploadImage(image, for: workOrderId, itemId: itemId)
                uploadedURLs.append(imageURL)
                
                // Update progress
                uploadProgress = Double(index + 1) / Double(totalImages)
                
            } catch {
                setError("Failed to upload image \(index + 1): \(error.localizedDescription)")
                throw error
            }
        }
        
        return uploadedURLs
    }
    
    /// Delete an image from Firebase Storage
    func deleteImage(_ imageURL: String) async throws {
        do {
            guard let url = URL(string: imageURL) else {
                throw ImageError.invalidURL
            }
            
            let imageRef = storage.reference(forURL: imageURL)
            try await imageRef.delete()
            
        } catch {
            setError("Failed to delete image: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Delete multiple images from Firebase Storage
    func deleteImages(_ imageURLs: [String]) async throws {
        for imageURL in imageURLs {
            try await deleteImage(imageURL)
        }
    }
    
    /// Get image URLs for a work order item
    func getImageURLs(for workOrderId: String, itemId: UUID) async throws -> [String] {
        do {
            let imageRef = storage.reference().child("workOrders/\(workOrderId)/items/\(itemId)/images")
            let result = try await imageRef.listAll()
            
            var imageURLs: [String] = []
            for item in result.items {
                let url = try await item.downloadURL().absoluteString
                imageURLs.append(url)
            }
            
            return imageURLs
            
        } catch {
            setError("Failed to get image URLs: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get thumbnail URLs for a work order item
    func getThumbnailURLs(for workOrderId: String, itemId: UUID) async throws -> [String] {
        do {
            let thumbnailRef = storage.reference().child("workOrders/\(workOrderId)/items/\(itemId)/thumbnails")
            let result = try await thumbnailRef.listAll()
            
            var thumbnailURLs: [String] = []
            for item in result.items {
                let url = try await item.downloadURL().absoluteString
                thumbnailURLs.append(url)
            }
            
            return thumbnailURLs
            
        } catch {
            setError("Failed to get thumbnail URLs: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Image Processing Extensions
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}


