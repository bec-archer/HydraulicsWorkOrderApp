//
//  StorageImageResolver.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/12/25.
//


// ───── StorageImageResolver.swift ─────

import Foundation
import FirebaseStorage

/// Resolves a Firebase Storage path or gs:// URL into a downloadable https:// URL
struct StorageImageResolver {
    
    static func resolve(_ pathOrUrl: String, completion: @escaping (URL?) -> Void) {
        
        // If it’s already an https URL, return immediately
        if pathOrUrl.lowercased().hasPrefix("http") {
            completion(URL(string: pathOrUrl))
            return
        }
        
        // Get a reference for either gs:// or relative path
        let storageRef: StorageReference
        if pathOrUrl.lowercased().hasPrefix("gs://") {
            storageRef = Storage.storage().reference(forURL: pathOrUrl)
        } else {
            storageRef = Storage.storage().reference(withPath: pathOrUrl)
        }
        
        // Fetch a one-time download URL
        storageRef.downloadURL { url, error in
            if let error = error {
                print("❌ StorageImageResolver failed: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(url)
            }
        }
    }
}
// END
