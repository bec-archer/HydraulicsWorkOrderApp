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

    // ───── Upload WO_Item Image ─────
    // Stores under: intake/{woItemId}/yyyyMMdd_HHmmss_SSS.jpg
    // Returns the public download URL string on success.
    func uploadWOItemImage(_ image: UIImage, woItemId: UUID) async throws -> String {
        // 1) Compress for network; tweak quality if needed
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not encode image"])
        }

        // 2) Build path
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let filename = df.string(from: Date()) + ".jpg"
        let path = "intake/\(woItemId.uuidString)/\(filename)"
        let ref = root.child(path)

        // 3) Metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

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
