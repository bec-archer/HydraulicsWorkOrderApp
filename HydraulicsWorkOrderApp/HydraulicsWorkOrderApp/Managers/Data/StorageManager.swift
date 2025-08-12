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

    // ───── Singleton (stateless, but handy) ─────
    static let shared = StorageManager()

    private let root = Storage.storage().reference()

    // ───── Path Builder (centralized) ─────
    // Organized by WorkOrder → WO_Item → filename
    private func intakePath(woId: String, woItemId: UUID, filename: String) -> String {
        "intake/\(woId)/\(woItemId.uuidString)/\(filename)"
    }


    // ───── Upload WO_Item Image ─────
    // Stores under: intake/{woId}/{woItemId}/yyyyMMdd_HHmmss_SSS.jpg
    // Returns the public download URL string on success.
    func uploadWOItemImage(_ image: UIImage, woId: String, woItemId: UUID) async throws -> String {
        // 1) Compress for network
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "StorageManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not encode image"])
        }

        // 2) Build path using centralized helper
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let filename = df.string(from: Date()) + ".jpg"
        let path = intakePath(woId: woId, woItemId: woItemId, filename: filename)
        let ref = root.child(path)

        // 3) Metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=86400"

        // 4) Upload (async/await)
        _ = try await ref.putDataAsync(data, metadata: metadata)

        // 5) Fetch download URL
        let url = try await ref.downloadURL()
        return url.absoluteString
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
