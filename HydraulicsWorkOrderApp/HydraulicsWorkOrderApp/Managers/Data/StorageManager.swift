//
//  StorageManager.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/11/25.
//

import Foundation
import UIKit
import SwiftUI          // ← add this so #Preview can see Text
import FirebaseStorage

// ─────────────────────────────────────────────────────────────
// 📦 StorageManager
// Handles uploads to Firebase Storage for WO_Item images
// ─────────────────────────────────────────────────────────────

struct StorageManager {
    
    // ───── Debug Toggle (flip to true to see Storage logs) ─────
    // Keeping this here avoids scheme/env edits and keeps noise out by default.
    static var verboseLogging: Bool = false

    // Small helper so we never scatter `if DEBUG` across the file
    @inline(__always) private func dprint(_ message: @autoclosure () -> String) {
        if StorageManager.verboseLogging { Swift.print(message()) }
    }
    // END

    init() {
        // Short, predictable retries for a snappy UX
        Storage.storage().maxUploadRetryTime = 15
        Storage.storage().maxOperationRetryTime = 10
    }

    // ───── Singleton (stateless, but handy) ─────
    static let shared = StorageManager()


    private let root = Storage.storage().reference()
    // ───── Track In-Flight Uploads to Prevent Duplicates ─────
    private static var inFlightUploads = Set<String>()
    private static let inFlightQueue = DispatchQueue(label: "StorageManager.inFlightQueue")
    // END


    // ───── Path Builder (centralized) ─────
    // Organized by WorkOrder → WO_Item → filename
    private func intakePath(woId: String, woItemId: UUID, filename: String) -> String {
        "intake/\(woId)/\(woItemId.uuidString)/\(filename)"
    }


    // ───── Upload WO_Item Image ─────
    // Stores under: intake/{woId}/{woItemId}/yyyyMMdd_HHmmss_SSS.jpg
    // Returns the public download URL string on success.
    func uploadWOItemImage(_ image: UIImage, woId: String, woItemId: UUID) async throws -> String {

        // ───── Shared timestamp for both de‑dupe & path ─────
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let stamp = df.string(from: Date())
        let filename = "\(stamp).jpg"
        let path = intakePath(woId: woId, woItemId: woItemId, filename: filename)

        // ───── Prevent Duplicate Uploads ─────
        var insertedKey = false
        StorageManager.inFlightQueue.sync {
            if !StorageManager.inFlightUploads.contains(path) {
                _ = StorageManager.inFlightUploads.insert(path)
                insertedKey = true
            }
        }
        guard insertedKey else {
            dprint("⚠️ Skipping duplicate upload for \(path)")
            return ""
        }
        // Always remove the key on ANY exit (success, error, or early return)
        defer {
            StorageManager.inFlightQueue.sync {
                _ = StorageManager.inFlightUploads.remove(path)
            }
        }
        // END Prevent Duplicate Uploads



        // 1) Compress for network (resizes + strips metadata)
        //    Target ~100–400KB for typical iPad photos
        guard let compressed = ImageCompressionManager.compressForUpload(
            image,
            maxDimension: 1600,
            jpegQuality: 0.7,
            thumbMaxDimension: 400,
            thumbQuality: 0.6
        ) else {
            throw NSError(domain: "StorageManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Image compression failed"])
        }

        let data = compressed.fullData
        dprint("📦 Uploading image ~\(compressed.approxKB) KB, px=\(Int(compressed.fullPixelSize.width))×\(Int(compressed.fullPixelSize.height))")

        // 2) Build path using centralized helper (same timestamp as de‑dupe)
        let ref = root.child(path)


        // 3) Metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg" // compressed.contentType, kept explicit
        metadata.cacheControl = "public, max-age=86400"

        // 4) Upload (async/await)
        _ = try await ref.putDataAsync(data, metadata: metadata)

        // 5) Fetch download URL
        let url = try await ref.downloadURL()

        return url.absoluteString
    }

    // ───── Upload WO_Item Image + Thumbnail ─────
    // Stores:
    //  - full:   intake/{woId}/{woItemId}/yyyyMMdd_HHmmss_SSS.jpg
    //  - thumb:  intake/{woId}/{woItemId}/thumbs/yyyyMMdd_HHmmss_SSS.jpg
    // Returns: (fullURL, thumbURL)
    func uploadWOItemImageWithThumbnail(_ image: UIImage, woId: String, woItemId: UUID) async throws -> (fullURL: String, thumbURL: String) {

        // ───── Shared timestamp for both de‑dupe & paths ─────
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let stamp = df.string(from: Date())
        let fullName  = "\(stamp).jpg"
        let thumbName = "\(stamp).jpg"

        let fullPath  = intakePath(woId: woId, woItemId: woItemId, filename: fullName)
        let thumbPath = intakePath(woId: woId, woItemId: woItemId, filename: "thumbs/\(thumbName)")
        let combinedKey = "\(fullPath)|\(thumbPath)"

        // ───── Prevent Duplicate Uploads ─────
        var insertedKey = false
        StorageManager.inFlightQueue.sync {
            if !StorageManager.inFlightUploads.contains(combinedKey) {
                _ = StorageManager.inFlightUploads.insert(combinedKey)
                insertedKey = true
            }
        }
        guard insertedKey else {
            dprint("⚠️ Skipping duplicate upload for \(combinedKey)")
            return ("", "")
        }
        // Always remove the key on ANY exit (success, error, or early return)
        defer {
            StorageManager.inFlightQueue.sync {
                _ = StorageManager.inFlightUploads.remove(combinedKey)
            }
        }
        // END Prevent Duplicate Uploads

        // ───── 1) Compress (full + thumb) ─────
        guard let compressed = ImageCompressionManager.compressForUpload(
            image,
            maxDimension: 1600,   // long-edge for full
            jpegQuality: 0.7,
            thumbMaxDimension: 400,
            thumbQuality: 0.6
        ) else {
            throw NSError(domain: "StorageManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Image compression failed"])
        }


        let fullRef  = root.child(fullPath)
        let thumbRef = root.child(thumbPath)

        // ───── 3) Metadata (cache for a day) ─────
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        meta.cacheControl = "public, max-age=86400"

        // ───── 4) Upload both (await) ─────
        // 🔧 Ensure FULL upload respects 5 MB rule (even if upstream changes)
        let fullUIImage = UIImage(data: compressed.fullData) ?? image
        let cappedFullData = jpegDataUnderLimit(fullUIImage) ?? compressed.fullData

        dprint("📤 Uploading FULL ~\(cappedFullData.count / 1024) KB → \(fullPath)")
        do {
            _ = try await fullRef.putDataAsync(cappedFullData, metadata: meta)
        } catch {
            // One quick retry (transient network hiccups happen)
            dprint("⚠️ Full upload failed, retrying once: \(error.localizedDescription)")
            _ = try await fullRef.putDataAsync(cappedFullData, metadata: meta)
        }


        dprint("📤 Uploading THUMB ~\(compressed.thumbnailData.count / 1024) KB → \(thumbPath)")
        _ = try await thumbRef.putDataAsync(compressed.thumbnailData, metadata: meta)

        // ───── 5) URLs ─────
        async let fullURLTask  = fullRef.downloadURL()
        async let thumbURLTask = thumbRef.downloadURL()
        let (fullURL, thumbURL) = try await (fullURLTask, thumbURLTask)
        

        return (fullURL.absoluteString, thumbURL.absoluteString)
    }
    // ───── Helpers: Cap to < 5 MB for Firebase rules ─────
    private func jpegDataUnderLimit(_ image: UIImage,
                                    startQuality: CGFloat = 0.8,
                                    minQuality: CGFloat = 0.4,
                                    maxBytes: Int = 4_800_000) -> Data? {
        var q = startQuality
        guard var data = image.jpegData(compressionQuality: q) else { return nil }
        if data.count <= maxBytes { return data }

        while q > minQuality {
            q -= 0.1
            if let d = image.jpegData(compressionQuality: q) {
                data = d
                if data.count <= maxBytes { return data }
            } else {
                break
            }
        }
        return data.count <= maxBytes ? data : nil
    }

    // END
}


// ───── Preview Template ─────
// (No UI to preview; keep file consistent)
#Preview {
    Text("StorageManager ready")
        .padding()
}
// END FILE
