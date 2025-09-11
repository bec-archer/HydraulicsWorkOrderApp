import SwiftUI
import FirebaseStorage
import Combine

// MARK: - ImageError Enum
enum ImageError: Error, LocalizedError {
    case compressionFailed
    case thumbnailCreationFailed
    case invalidURL
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .thumbnailCreationFailed:
            return "Failed to create thumbnail"
        case .invalidURL:
            return "Invalid image URL"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}



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
    func uploadSingleImage(_ image: UIImage, for workOrderId: String, itemId: UUID) async throws -> (imageURL: String, thumbnailURL: String) {
        print("🔍 DEBUG: uploadSingleImage called - Size: \(image.size)")
        
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
            
            // Generate timestamp-based filename for proper ordering
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
            let timestamp = dateFormatter.string(from: Date())
            let filename = "\(timestamp).jpg"
            let imagePath = "workOrders/\(workOrderId)/items/\(itemId)/images/\(filename)"
            let thumbnailPath = "workOrders/\(workOrderId)/items/\(itemId)/thumbnails/\(filename)"
            
            print("🔍 DEBUG: Generated filename: \(filename)")
            print("🔍 DEBUG: Image path: \(imagePath)")
            print("🔍 DEBUG: Thumbnail path: \(thumbnailPath)")
            
            // Upload main image
            let imageRef = storage.reference().child(imagePath)
            let imageMetadata = StorageMetadata()
            imageMetadata.contentType = "image/jpeg"
            
            let imageUploadTask: StorageUploadTask = imageRef.putData(compressedImageData, metadata: imageMetadata)
            
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
            
            // Wait for both uploads to complete using completion handlers
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                imageUploadTask.observe(.success) { snapshot in
                    continuation.resume(returning: snapshot.metadata!)
                }
                imageUploadTask.observe(.failure) { snapshot in
                    continuation.resume(throwing: snapshot.error!)
                }
            }
            
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                thumbnailUploadTask.observe(.success) { snapshot in
                    continuation.resume(returning: snapshot.metadata!)
                }
                thumbnailUploadTask.observe(.failure) { snapshot in
                    continuation.resume(throwing: snapshot.error!)
                }
            }
            
            // Get download URLs
            let imageURL = try await imageRef.downloadURL().absoluteString
            let thumbnailURL = try await thumbnailRef.downloadURL().absoluteString
            
            print("🔍 DEBUG: Upload completed successfully!")
            print("🔍 DEBUG: Image URL: \(imageURL)")
            print("🔍 DEBUG: Thumbnail URL: \(thumbnailURL)")
            
            return (imageURL: imageURL, thumbnailURL: thumbnailURL)
            
        } catch {
            setError("Failed to upload image: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Upload multiple images and return both image and thumbnail URLs
    func uploadImages(_ images: [UIImage], for workOrderId: String, itemId: UUID) async throws -> (imageURLs: [String], thumbnailURLs: [String]) {
        print("🔍 DEBUG: ImageManagementService.uploadImages called with \(images.count) images")
        print("🔍 DEBUG: workOrderId: \(workOrderId), itemId: \(itemId)")
        
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        defer {
            isUploading = false
            uploadProgress = 0.0
        }
        
        var uploadedImageURLs: [String] = []
        var uploadedThumbnailURLs: [String] = []
        let totalImages = images.count
        
        for (index, image) in images.enumerated() {
            print("🔍 DEBUG: Processing image[\(index)] - Size: \(image.size)")
            do {
                let result = try await uploadSingleImage(image, for: workOrderId, itemId: itemId)
                uploadedImageURLs.append(result.imageURL)
                uploadedThumbnailURLs.append(result.thumbnailURL)
                print("🔍 DEBUG: Image[\(index)] uploaded successfully - Image: \(result.imageURL), Thumbnail: \(result.thumbnailURL)")
                
                // Update progress
                uploadProgress = Double(index + 1) / Double(totalImages)
                
            } catch {
                print("🔍 DEBUG: Image[\(index)] upload failed: \(error.localizedDescription)")
                setError("Failed to upload image \(index + 1): \(error.localizedDescription)")
                throw error
            }
        }
        
        print("🔍 DEBUG: All images uploaded. Final order:")
        for (index, url) in uploadedImageURLs.enumerated() {
            print("🔍 DEBUG:   Final[\(index)]: \(url)")
        }
        
        return (imageURLs: uploadedImageURLs, thumbnailURLs: uploadedThumbnailURLs)
    }
    
    /// Delete an image from Firebase Storage
    func deleteImage(_ imageURL: String) async throws {
        do {
            guard URL(string: imageURL) != nil else {
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
            
            // Sort by timestamp in filename to maintain upload order
            imageURLs.sort { url1, url2 in
                return extractTimestampFromURL(url1) < extractTimestampFromURL(url2)
            }
            
            return imageURLs
            
        } catch {
            setError("Failed to get image URLs: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get thumbnail URLs for a work order item
    func getThumbnailURLs(for workOrderId: String, itemId: UUID) async throws -> [String] {
        print("🔍 DEBUG: getThumbnailURLs called for workOrderId: \(workOrderId), itemId: \(itemId)")
        
        do {
            let thumbnailRef = storage.reference().child("workOrders/\(workOrderId)/items/\(itemId)/thumbnails")
            let result = try await thumbnailRef.listAll()
            
            print("🔍 DEBUG: Found \(result.items.count) thumbnail files in Firebase Storage")
            
            var thumbnailURLs: [String] = []
            for (index, item) in result.items.enumerated() {
                let url = try await item.downloadURL().absoluteString
                thumbnailURLs.append(url)
                print("🔍 DEBUG: Thumbnail[\(index)]: \(item.name) -> \(url)")
            }
            
            // Sort by timestamp in filename to maintain upload order
            thumbnailURLs.sort { url1, url2 in
                return extractTimestampFromURL(url1) < extractTimestampFromURL(url2)
            }
            
            print("🔍 DEBUG: Returning \(thumbnailURLs.count) thumbnail URLs (sorted by timestamp)")
            return thumbnailURLs
            
        } catch {
            print("🔍 DEBUG: getThumbnailURLs failed: \(error.localizedDescription)")
            setError("Failed to get thumbnail URLs: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    /// Extract timestamp from Firebase Storage URL for sorting
    private func extractTimestampFromURL(_ url: String) -> String {
        // Extract filename from URL and get the timestamp part
        // URL format: .../workOrders/.../items/.../images/YYYYMMDD_HHMMSS_SSS.jpg
        if let lastSlash = url.lastIndex(of: "/") {
            let filename = String(url[url.index(after: lastSlash)...])
            // Remove .jpg extension and return the timestamp part
            if let dotIndex = filename.lastIndex(of: ".") {
                return String(filename[..<dotIndex])
            }
        }
        // Fallback: return the full URL if we can't extract timestamp
        return url
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


