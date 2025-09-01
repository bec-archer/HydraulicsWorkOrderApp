import SwiftUI

struct WorkOrderItemImagesView: View {
    let item: WO_Item
    let itemIndex: Int
    let onImageSelected: (URL) -> Void
    let onShowAllThumbs: () -> Void
    
    @State private var selectedImageURL: URL?
    @State private var showImageViewer = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ── Primary Image
            if let firstUrl = URL(string: item.imageUrls[0]) {
                Button {
                    selectedImageURL = firstUrl
                    showImageViewer = true
                } label: {
                    AsyncImage(url: firstUrl) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        case .success(let image):
                            image
                                .renderingMode(.original)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .mask {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                }
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .clipped()
                                .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
                        case .failure:
                            Color.gray
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
                        @unknown default:
                            Color.gray
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            // ── Thumbnail Grid using LazyVGrid
            if item.imageUrls.count > 1 {
                let additionalImages = Array(item.imageUrls.dropFirst())
                let displayImages = Array(additionalImages.prefix(4)) // Show up to 4 thumbnails
                let extraCount = max(0, additionalImages.count - displayImages.count)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(Array(displayImages.enumerated()), id: \.offset) { idx, urlString in
                        if let url = URL(string: urlString) {
                            Button {
                                if extraCount > 0 && idx == displayImages.count - 1 {
                                    onShowAllThumbs()
                                } else {
                                    selectedImageURL = url
                                    showImageViewer = true
                                }
                            } label: {
                                ZStack {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                                                .aspectRatio(1, contentMode: .fit)
                                        case .success(let img):
                                            img.renderingMode(.original)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .mask {
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                }
                                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                                                .aspectRatio(1, contentMode: .fit)
                                                .clipped()
                                                .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
                                        case .failure:
                                            Color.gray
                                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                                                .aspectRatio(1, contentMode: .fit)
                                                .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
                                        @unknown default:
                                            Color.gray
                                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                                                .aspectRatio(1, contentMode: .fit)
                                                .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
                                        }
                                    }
                                    
                                    // Overlay for additional images indicator
                                    if extraCount > 0 && idx == displayImages.count - 1 {
                                        Rectangle()
                                            .fill(Color.black.opacity(0.35))
                                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                                            .aspectRatio(1, contentMode: .fit)
                                            .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
                                        Text("+\(extraCount)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .fullScreenCover(isPresented: $showImageViewer) {
            if let selectedImageURL = selectedImageURL {
                FullScreenImageViewer(imageURL: selectedImageURL, isPresented: $showImageViewer)
            }
        }
        .onChange(of: selectedImageURL) { newValue in
            if let url = newValue {
                onImageSelected(url)
            }
        }
    }
}

#Preview {
    let sampleItem: WO_Item = {
        var item = WO_Item.sample
        item.imageUrls = [
            "https://example.com/image1.jpg",
            "https://example.com/image2.jpg",
            "https://example.com/image3.jpg"
        ]
        return item
    }()
    
    return WorkOrderItemImagesView(
        item: sampleItem,
        itemIndex: 0,
        onImageSelected: { _ in },
        onShowAllThumbs: { }
    )
    .frame(width: 200, height: 300)
    .background(Color.gray.opacity(0.1))
}
