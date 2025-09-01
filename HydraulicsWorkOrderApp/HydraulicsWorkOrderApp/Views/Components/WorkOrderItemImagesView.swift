import SwiftUI

// ⚠️  CRITICAL: DO NOT MODIFY IMAGE SIZES OR SPACING WITHOUT TESTING! ⚠️
// 
// This file contains carefully calibrated image dimensions and spacing that took
// significant time to perfect. The current layout provides:
//
// PRIMARY IMAGE:
// - Size: 300x300px (perfect for visibility without overwhelming the card)
// - Rounded corners: 8px radius for consistent styling
//
// THUMBNAIL GRID:
// - Container width: 300px (inherits primary image width for perfect alignment)
// - Thumbnail size: 142x142px each (large enough to be useful, small enough to fit)
// - Grid spacing: 8px between thumbnails (matches VStack spacing above)
// - Columns: 2 fixed-width columns (GridItem.fixed(142)) for predictable layout
//
// SPACING SYSTEM:
// - VStack spacing: 8px (between primary image and thumbnail grid)
// - LazyVGrid spacing: 8px (between thumbnail rows - MUST match VStack spacing)
// - Result: Perfect visual rhythm and alignment
//
// 🚨  WARNING: Changing any of these values will break the carefully balanced layout!
// 🚨  If you must modify, test thoroughly and update this comment with new values!
// 🚨  The 300px container width MUST match the primary image width for alignment!
//
// Last calibrated: [Current Date] - Primary: 300x300, Thumbnails: 142x142, Spacing: 8px
// ================================================================================

struct WorkOrderItemImagesView: View {
    let item: WO_Item
    @Binding var selectedImageURL: URL?
    @Binding var showImageViewer: Bool
    var onShowAllThumbs: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primary Image
            if !item.imageUrls.isEmpty, let firstUrl = URL(string: item.imageUrls[0]) {
                Button {
                    selectedImageURL = firstUrl
                    showImageViewer = true
                } label: {
                    StableImageLoader(url: firstUrl, showOverlay: false)
                        .frame(width: 300, height: 300)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 300, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            // Thumbnail Grid
            if item.imageUrls.count > 1 {
                let displayImages = Array(item.imageUrls.dropFirst())
                let maxThumbnails = 4
                let thumbnailsToShow = Array(displayImages.prefix(maxThumbnails))
                let hasMoreImages = displayImages.count > maxThumbnails
                
                LazyVGrid(columns: [
                    GridItem(.fixed(142)),
                    GridItem(.fixed(142))
                ], spacing: 8) {
                    ForEach(Array(thumbnailsToShow.enumerated()), id: \.offset) { idx, urlString in
                        Button {
                            if idx == 3 && hasMoreImages {
                                onShowAllThumbs?()
                            } else if let url = URL(string: urlString) {
                                selectedImageURL = url
                                showImageViewer = true
                            }
                        } label: {
                            StableImageLoader(url: URL(string: urlString)!, showOverlay: idx == 3 && hasMoreImages, overlayText: "+\(displayImages.count - maxThumbnails)")
                                .frame(width: 142, height: 142)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 300)
            }
        }
        .padding(.horizontal, 16)
    }
    

}

struct StableImageLoader: View {
    let url: URL
    let showOverlay: Bool
    let overlayText: String
    @State private var image: UIImage?
    @State private var isLoading = true
    
    init(url: URL, showOverlay: Bool = false, overlayText: String = "") {
        self.url = url
        self.showOverlay = showOverlay
        self.overlayText = overlayText
    }
    
    var body: some View {
        ZStack {
            // Background image or placeholder
            if let image = image {
                Image(uiImage: image)
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else if isLoading {
                ProgressView()
            } else {
                Color.gray
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    )
            }
            
            // Overlay
            if showOverlay {
                Color.black.opacity(0.5)
                Text(overlayText)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let loadedImage = UIImage(data: data) {
                    self.image = loadedImage
                }
            }
        }.resume()
    }
}

#Preview {
    WorkOrderItemImagesView(
        item: {
            var item = WO_Item.create()
            item.type = "Sample Item"
            item.imageUrls = [
                "https://example.com/image1.jpg",
                "https://example.com/image2.jpg",
                "https://example.com/image3.jpg",
                "https://example.com/image4.jpg",
                "https://example.com/image5.jpg"
            ]
            return item
        }(),
        selectedImageURL: .constant(nil),
        showImageViewer: .constant(false),
        onShowAllThumbs: {}
    )
    .padding()
}
