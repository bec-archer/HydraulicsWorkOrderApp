//  ItemCard.swift
//  HydraulicsWorkOrderApp

import SwiftUI
import PhotosUI
import UIKit

/*  ────────────────────────────────────────────────────────────────────────────
    WARNING — LOCKED VIEW (GUARDRAIL)
    GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT

    This view's layout, UI, and behavior are CRITICAL to the workflow and tests.
    DO NOT change, refactor, or alter layout/styling/functionality in this file.

    Allowed edits ONLY:
      • Comments and documentation
      • Preview sample data (non-shipping)
      • Bugfixes that are 100% no-visual-change (must be verifiable in Preview)

    Any change beyond the above requires explicit approval from Bec.
    Rationale: This screen matches shop SOPs and downstream QA expectations.
    ──────────────────────────────────────────────────────────────────────────── */

// ───── Image URL Resolver (thumb ↔ full, zipped) ─────
// Keeps thumbnail and full-size arrays paired to prevent mismatches.
// Uses zip so UI never indexes past bounds even if one array lags temporarily.
private func resolvedURL(for item: WO_Item, at index: Int) -> URL? {
    let pairs = Array(zip(item.thumbUrls, item.imageUrls))
    
    // Preferred: use zipped pair at index
    if pairs.indices.contains(index) {
        let (_, full) = pairs[index]
        if let url = URL(string: full), !full.isEmpty {
            print("🖼️ tapped(full paired): \(full)")
            return url
        }
    }
    
    // Fallbacks: first valid full, then first valid thumb
    if let firstFull = item.imageUrls.first, let url = URL(string: firstFull), !firstFull.isEmpty {
        print("🖼️ tapped(fallback full first): \(firstFull)")
        return url
    }
    if let firstThumb = item.thumbUrls.first, let url = URL(string: firstThumb), !firstThumb.isEmpty {
        print("🖼️ tapped(fallback thumb first): \(firstThumb)")
        return url
    }
    
    print("🖼️ tapped: no valid URL for item \(item.id)")
    return nil
}

// ───── ITEM CARD ─────
// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.
struct ItemCard: View {
    let item: WO_Item

    // Bindings into the item's image arrays so uploads attach to THIS item
    @Binding var imageURLs: [String]
    @Binding var thumbURLs: [String]
    
    // Optional: enable debug mode for Xcode selection
    var debugSelectable: Bool = false
    
    // Optional: callback when images change
    var onImagesChanged: (() -> Void)? = nil
    
    // Status colors for the status badge
    private let statusColors = [
        "Checked In": Color.blue,
        "In Progress": Color.orange,
        "Test Failed": Color.red,
        "Completed": Color.green,
        "Closed": Color.gray
    ]
    
    // Status options for dropdown
    private let statusOptions = [
        "Checked In",
        "In Progress",
        "Test Failed",
        "Completed",
        "Closed"
    ]

    var body: some View {
        // Large primary (1:1) above a 2×2 grid of thumbs (2, 3, 4, +Qty)
        GeometryReader { geo in
            // Container paddings/spacings
            let horizontalPadding: CGFloat = 0          // parent can add its own
            let gridSpacing: CGFloat = 8
            let maxPrimary: CGFloat = 640               // cap per spec (600–700pt guard)
            let available = geo.size.width - horizontalPadding
            let primarySize = min(available, maxPrimary)
            let thumbSize = (primarySize - gridSpacing) / 2.0

            VStack(alignment: .leading, spacing: 10) {
                // PRIMARY 1:1 IMAGE (first imageURLs)
                if let first = imageURLs.first, !first.isEmpty, let url = URL(string: first) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholderPrimary(size: primarySize)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()                // crop, do not stretch
                                .frame(width: primarySize, height: primarySize)
                                .clipped()
                                .cornerRadius(12)              // slightly inside card radius
                        case .failure(_):
                            placeholderPrimary(size: primarySize)
                        @unknown default:
                            placeholderPrimary(size: primarySize)
                        }
                    }
                } else {
                    // No images — show primary placeholder
                    placeholderPrimary(size: primarySize)
                }

                // THUMBNAIL GRID (2×2 under primary)
                let extra = Array(imageURLs.dropFirst())
                if !extra.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.fixed(thumbSize), spacing: gridSpacing),
                                  GridItem(.fixed(thumbSize), spacing: gridSpacing)],
                        spacing: gridSpacing
                    ) {
                        // up to next three real thumbs (2,3,4 is handled by +Qty as needed)
                        ForEach(Array(extra.prefix(3).enumerated()), id: \.offset) { _, urlStr in
                            if let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        placeholderThumb(size: thumbSize)
                                    case .success(let img):
                                        img.resizable()
                                            .scaledToFill()
                                            .frame(width: thumbSize, height: thumbSize)
                                            .clipped()
                                            .cornerRadius(10)
                                    case .failure(_):
                                        placeholderThumb(size: thumbSize)
                                    @unknown default:
                                        placeholderThumb(size: thumbSize)
                                    }
                                }
                            } else {
                                placeholderThumb(size: thumbSize)
                            }
                        }

                        // If more than 4 total images, show +Qty on the final cell
                        if imageURLs.count > 4 {
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: thumbSize, height: thumbSize)
                                    .cornerRadius(10)
                                Text("+\(imageURLs.count - 4)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        } else if extra.count >= 2 {
                            // Fill the 4th cell when exactly 3 extras exist
                            if extra.count == 3 {
                                // already filled 3 cells above; add a 4th empty to keep grid shape
                                Rectangle()
                                    .fill(Color.gray.opacity(0.08))
                                    .frame(width: thumbSize, height: thumbSize)
                                    .cornerRadius(10)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 18, weight: .regular))
                                            .foregroundColor(.secondary)
                                    )
                            }
                        }
                    }
                    .frame(width: primarySize, alignment: .leading) // grid width == primary width
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 0) // allow parent to size vertically
    }
    
    @ViewBuilder
    private func placeholderPrimary(size: CGFloat) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: size * 0.12, weight: .regular))
                    .foregroundColor(.secondary)
            )
            .cornerRadius(12)
    }

    @ViewBuilder
    private func placeholderThumb(size: CGFloat) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
            )
            .cornerRadius(10)
    }
}

// ───── Status Color Helper ─────
private func statusColor(for status: String) -> Color {
    switch status {
    case "Checked In":     return UIConstants.StatusColors.checkedIn
    case "In Progress":    return UIConstants.StatusColors.inProgress
    case "Test Failed":    return UIConstants.StatusColors.testFailed
    case "Completed":      return UIConstants.StatusColors.completed
    case "Closed":         return UIConstants.StatusColors.closed
    default:               return UIConstants.StatusColors.fallback
    }
}

// ───── Local helper used only in note save ─────
private func compressForFirebase(_ image: UIImage) -> UIImage {
    // Simple compression without resizing for now
    guard let data = image.jpegData(compressionQuality: 0.85) else { return image }
    return UIImage(data: data) ?? image
}

// ───── Camera bridge for note modal (no nested sheets) ─────
private struct NoteCameraCaptureView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: NoteCameraCaptureView
        
        init(_ parent: NoteCameraCaptureView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// ───── PREVIEW TEMPLATE ─────
#Preview("Item Card") {
    let sampleItem = WO_Item.sample
    ItemCard(
        item: sampleItem,
        imageURLs: .constant(sampleItem.imageUrls),
        thumbURLs: .constant(sampleItem.thumbUrls)
    )
    .padding(.vertical, 12)
    .background(Color(.systemBackground))
}

// Preview for Selectable: disables all interactions, enables debugSelectable for Xcode selection
#Preview("Item Card (Selectable)") {
    let sampleItem = WO_Item.sample
    ItemCard(
        item: sampleItem,
        imageURLs: .constant(sampleItem.imageUrls),
        thumbURLs: .constant(sampleItem.thumbUrls),
        debugSelectable: true
    )
    .padding(.vertical, 12)
    .background(Color(.systemBackground))
}
