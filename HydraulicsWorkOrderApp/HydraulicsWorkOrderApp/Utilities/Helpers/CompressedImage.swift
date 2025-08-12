//
//  CompressedImage.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/12/25.
//


import SwiftUI
import UIKit

// ───── ImageCompressionManager ─────
// Purpose: Resize & compress UIImages before upload to Firebase Storage.
// Notes:
// - Resizes to a given max dimension while preserving aspect ratio
// - Encodes as JPEG at a chosen quality
// - Draws into a new context to drop EXIF/location metadata
// - Also produces a smaller thumbnail (useful for gallery / cards)
// ───────────────────────────────────

struct CompressedImage {
    let fullData: Data                  // Final upload bytes
    let fullPixelSize: CGSize           // Pixel size of the uploaded image
    let thumbnailData: Data             // Small preview bytes
    let thumbnailPixelSize: CGSize      // Pixel size of the thumbnail
    let approxKB: Int                   // Quick sanity check for size budgeting
    let contentType: String             // "image/jpeg" (set on Storage metadata)
}

// MARK: - Public API
enum ImageCompressionManager {
    
    // ───── compressForUpload ─────
    // Main entry point: pass in a UIImage, get compressed upload Data + thumbnail.
    // Defaults chosen to keep images ~100–400KB for most iPad photos.
    // Adjust maxDimension / quality as needed.
    // ─────────────────────────────
    static func compressForUpload(
        _ image: UIImage,
        maxDimension: CGFloat = 1600,       // Long edge target for uploads
        jpegQuality: CGFloat = 0.7,         // 0.6–0.75 is a good sweet spot
        thumbMaxDimension: CGFloat = 400,   // Long edge for thumbnails
        thumbQuality: CGFloat = 0.6
    ) -> CompressedImage? {
        
        // 1) Resize main image
        guard let resized = resize(image, toMax: maxDimension) else { return nil }
        
        // 2) Encode as JPEG (drawing into context strips metadata)
        guard let fullData = jpegDataStrippingMetadata(from: resized, quality: jpegQuality) else { return nil }
        
        // 3) Build thumbnail
        guard let thumbUIImage = resize(image, toMax: thumbMaxDimension),
              let thumbnailData = jpegDataStrippingMetadata(from: thumbUIImage, quality: thumbQuality)
        else { return nil }
        
        let approxKB = Int(ceil(Double(fullData.count) / 1024.0))
        
        return CompressedImage(
            fullData: fullData,
            fullPixelSize: CGSize(width: resized.size.width * resized.scale,
                                  height: resized.size.height * resized.scale),
            thumbnailData: thumbnailData,
            thumbnailPixelSize: CGSize(width: thumbUIImage.size.width * thumbUIImage.scale,
                                       height: thumbUIImage.size.height * thumbUIImage.scale),
            approxKB: approxKB,
            contentType: "image/jpeg"
        )
    }
}

// MARK: - Helpers

// ───── resize(toMax:) ─────
// Downscales an image so its longer edge = maxDimension (keeps aspect ratio)
// Uses high quality interpolation.
// ──────────────────────────
private func resize(_ image: UIImage, toMax maxDimension: CGFloat) -> UIImage? {
    let width = image.size.width
    let height = image.size.height
    let maxEdge = max(width, height)
    
    // If already small enough, return as-is
    guard maxEdge > maxDimension else { return image }
    
    let scale = maxDimension / maxEdge
    let newSize = CGSize(width: floor(width * scale), height: floor(height * scale))
    
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1          // We’re drawing in pixel space intentionally
    format.opaque = false
    
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    let result = renderer.image { ctx in
        ctx.cgContext.interpolationQuality = .high
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return result
}

// ───── jpegDataStrippingMetadata ─────
// Re-renders the image and encodes as JPEG. This drops EXIF/GPS metadata by
// design (we’re not copying metadata over).
// ─────────────────────────────────────
private func jpegDataStrippingMetadata(from image: UIImage, quality: CGFloat) -> Data? {
    // Ensure we have a CGImage-backed image for reliable encoding
    guard let cgImage = image.cgImage else { return image.jpegData(compressionQuality: quality) }
    
    // Draw into a fresh context to ensure no metadata survives
    let size = CGSize(width: cgImage.width, height: cgImage.height)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    let flattened = renderer.image { _ in
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
    }
    
    return flattened.jpegData(compressionQuality: quality)
}

// ───── DEBUG Preview (Utility) ─────
// A tiny visual harness so Xcode Previews don’t complain.
// Shows example sizes for a system image run through the pipeline.
// ───────────────────────────────────
struct ImageCompressionManager_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            Text("ImageCompressionManager Preview")
                .font(.headline)
            
            let testImage = UIImage(systemName: "wrench.and.screwdriver")!
                .withTintColor(.black, renderingMode: .alwaysOriginal)
            
            if let compressed = ImageCompressionManager.compressForUpload(testImage, maxDimension: 512) {
                Text("Full approx: \(compressed.approxKB) KB")
                    .font(.subheadline)
                Text("Full px: \(Int(compressed.fullPixelSize.width)) × \(Int(compressed.fullPixelSize.height))")
                    .font(.caption)
                Text("Thumb px: \(Int(compressed.thumbnailPixelSize.width)) × \(Int(compressed.thumbnailPixelSize.height))")
                    .font(.caption2)
            } else {
                Text("Compression failed")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
} // END previews
