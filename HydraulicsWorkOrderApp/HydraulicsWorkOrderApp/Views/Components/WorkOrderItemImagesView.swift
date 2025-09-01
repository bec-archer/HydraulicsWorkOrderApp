import SwiftUI

struct WorkOrderItemImagesView: View {
    let item: WO_Item
    @Binding var selectedImageURL: URL?
    @Binding var showImageViewer: Bool
    var onShowAllThumbs: (() -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width, 200) // Ensure minimum width
            let primaryImageSize = availableWidth
            let thumbnailSize = (availableWidth - 6) / 2 // Account for 6pt spacing between thumbnails
            
            VStack(alignment: .leading, spacing: 6) {
                // Primary Image
                if !item.imageUrls.isEmpty, let firstUrl = URL(string: item.imageUrls[0]) {
                    Button {
                        selectedImageURL = firstUrl
                        showImageViewer = true
                    } label: {
                        StableImageLoader(url: firstUrl, fixedWidth: primaryImageSize)
                    }
                    .buttonStyle(.plain)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: primaryImageSize, height: primaryImageSize)
                        .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                
                // Thumbnail Grid
                if item.imageUrls.count > 1 {
                    let displayImages = Array(item.imageUrls.dropFirst())
                    
                    LazyVGrid(columns: [
                        GridItem(.fixed(thumbnailSize)),
                        GridItem(.fixed(thumbnailSize))
                    ], spacing: 6) {
                        ForEach(Array(displayImages.enumerated()), id: \.offset) { idx, urlString in
                            Button {
                                if idx == 3 && displayImages.count > 4 {
                                    onShowAllThumbs?()
                                } else if let url = URL(string: urlString) {
                                    selectedImageURL = url
                                    showImageViewer = true
                                }
                            } label: {
                                ZStack {
                                    StableImageLoader(url: URL(string: urlString)!, fixedWidth: thumbnailSize)
                                        .frame(width: thumbnailSize, height: thumbnailSize)
                                    
                                    if idx == 3 && displayImages.count > 4 {
                                        Color.black.opacity(0.5)
                                            .frame(width: thumbnailSize, height: thumbnailSize)
                                            .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
                                        
                                        Text("+\(displayImages.count - 4)")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(width: availableWidth, height: calculateTotalHeight(primaryImageSize: primaryImageSize, thumbnailSize: thumbnailSize, hasThumbnails: item.imageUrls.count > 1))
        }
        .frame(height: calculateEstimatedHeight(hasThumbnails: item.imageUrls.count > 1))
    }
    
    private func calculateTotalHeight(primaryImageSize: CGFloat, thumbnailSize: CGFloat, hasThumbnails: Bool) -> CGFloat {
        var height = primaryImageSize
        if hasThumbnails {
            height += 6 + thumbnailSize // spacing + thumbnail row height
        }
        return height
    }
    
    private func calculateEstimatedHeight(hasThumbnails: Bool) -> CGFloat {
        let estimatedPrimarySize: CGFloat = 280 // Increased to prevent cutoff
        let estimatedThumbnailSize: CGFloat = (estimatedPrimarySize - 6) / 2
        
        var height = estimatedPrimarySize
        if hasThumbnails {
            height += 6 + estimatedThumbnailSize
        }
        return height
    }
}

struct StableImageLoader: View {
    let url: URL
    let fixedWidth: CGFloat
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: fixedWidth, height: fixedWidth)
                    .clipped()
                    .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
            } else if isLoading {
                ProgressView()
                    .frame(width: fixedWidth, height: fixedWidth)
            } else {
                Color.gray
                    .frame(width: fixedWidth, height: fixedWidth)
                    .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    )
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
