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
        
        #if DEBUG
        print("🔄 StorageImageResolver.resolve called with: \(pathOrUrl)")
        #endif
        
        // If it's already an https URL, return immediately
        if pathOrUrl.lowercased().hasPrefix("http") {
            #if DEBUG
            print("✅ StorageImageResolver: Already HTTPS URL, returning directly")
            #endif
            completion(URL(string: pathOrUrl))
            return
        }
        
        // Get a reference for either gs:// or relative path
        let storageRef: StorageReference
        if pathOrUrl.lowercased().hasPrefix("gs://") {
            storageRef = Storage.storage().reference(forURL: pathOrUrl)
            #if DEBUG
            print("🔗 StorageImageResolver: Using gs:// reference")
            #endif
        } else {
            storageRef = Storage.storage().reference(withPath: pathOrUrl)
            #if DEBUG
            print("🔗 StorageImageResolver: Using relative path reference")
            #endif
        }
        
        // Fetch a one-time download URL
        storageRef.downloadURL { url, error in
            if let error = error {
                #if DEBUG
                print("❌ StorageImageResolver failed for \(pathOrUrl): \(error.localizedDescription)")
                #endif
                completion(nil)
            } else {
                #if DEBUG
                print("✅ StorageImageResolver succeeded for \(pathOrUrl): \(url?.absoluteString ?? "nil")")
                #endif
                completion(url)
            }
        }
    }
}
// END
