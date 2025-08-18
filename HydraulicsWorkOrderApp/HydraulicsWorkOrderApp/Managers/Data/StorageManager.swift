//
//  StorageManager.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//

import Foundation
import FirebaseStorage
import UIKit

class StorageManager {
    static let shared = StorageManager()

    // ───── Firebase Storage Root (uses correct bucket) ─────
    private let root = Storage.storage(url: "gs://hydraulicsworkorderapp.appspot.com").reference()

    // ───── Upload full-size photo (WorkOrder Item image) ─────
    func uploadWOItemImage(data: Data, itemId: UUID, completion: @escaping (Result<String, Error>) -> Void) {
        let path = "intake/\(itemId.uuidString)/\(UUID().uuidString).jpg"
        let ref = root.child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                print("❌ Upload failed for:", path)
                print("   └─ Error:", error.localizedDescription)
                completion(.failure(error))
            } else {
                print("📸 Uploaded image path:", path)
                completion(.success(path))
            }
        }
    }

    // ───── Upload image + thumbnail to thumbs/ folder ─────
    func uploadWOItemImageWithThumbnail(image: UIImage, itemId: UUID, completion: @escaping (Result<(String, String), Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8),
              let thumbnail = image.resized(to: CGSize(width: 240, height: 180)),
              let thumbData = thumbnail.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "Image encoding failed", code: -1)))
            return
        }

        let uuid = UUID().uuidString
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "")

        let fullPath = "intake/\(itemId.uuidString)/\(uuid).jpg"
        let thumbPath = "intake/\(itemId.uuidString)/thumbs/\(timestamp).jpg"

        let fullRef  = root.child(fullPath)
        let thumbRef = root.child(thumbPath)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let group = DispatchGroup()
        var fullResult: Result<String, Error>?
        var thumbResult: Result<String, Error>?

        print("📤 Starting upload:")
        print("   ├─ Full size:  \(fullPath)")
        print("   └─ Thumbnail:  \(thumbPath)")

        group.enter()
        fullRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                fullResult = .failure(error)
            } else {
                fullResult = .success(fullPath)
            }
            group.leave()
        }

        group.enter()
        thumbRef.putData(thumbData, metadata: metadata) { _, error in
            if let error = error {
                thumbResult = .failure(error)
            } else {
                thumbResult = .success(thumbPath)
            }
            group.leave()
        }

        group.notify(queue: .main) {
            if let f = try? fullResult?.get(), let t = try? thumbResult?.get() {
                print("✅ Uploaded full + thumb:", f, t)
                completion(.success((f, t)))
            } else {
                let error = {
                    if case let .failure(e)? = fullResult { return e }
                    if case let .failure(e)? = thumbResult { return e }
                    return NSError(domain: "Upload failed", code: -1)
                }()
                print("❌ One or more uploads failed:")
                print("   └─", error.localizedDescription)
                completion(.failure(error))
            }
        }
    }
}
// END

// ───── Image Resize Helper ─────
extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
