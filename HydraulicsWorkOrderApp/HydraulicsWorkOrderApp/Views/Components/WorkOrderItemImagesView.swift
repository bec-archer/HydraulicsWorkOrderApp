import SwiftUI

struct WorkOrderItemImagesView: View {
    let item: WO_Item
    @Binding var selectedImageURL: URL?
    @Binding var showImageViewer: Bool
    var onShowAllThumbs: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Primary Image
            if !item.imageUrls.isEmpty, let firstUrl = URL(string: item.imageUrls[0]) {
                Button {
                    selectedImageURL = firstUrl
                    showImageViewer = true
                } label: {
                    StableImageLoader(url: firstUrl)
                        .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)
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
                    GridItem(.flexible()),
                    GridItem(.flexible())
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
                                StableImageLoader(url: URL(string: urlString)!)
                                    .aspectRatio(1, contentMode: .fit)
                                
                                if idx == 3 && displayImages.count > 4 {
                                    Color.black.opacity(0.5)
                                        .aspectRatio(1, contentMode: .fit)
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
    }
    

}

struct StableImageLoader: View {
    let url: URL
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .mask { RoundedRectangle(cornerRadius: 8, style: .continuous) }
            } else if isLoading {
                ProgressView()
                    .aspectRatio(1, contentMode: .fit)
            } else {
                Color.gray
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
