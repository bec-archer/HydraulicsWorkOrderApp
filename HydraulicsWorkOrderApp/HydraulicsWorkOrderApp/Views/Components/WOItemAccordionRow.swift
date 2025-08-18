import Foundation
import SwiftUI
import PhotosUI
import UIKit

struct WOItemAccordionRow: View {
    // Two possible initialization patterns:
    
    // Simple mode with direct item binding
    @Binding var item: WO_Item?
    
    // Advanced mode (with index-based access)
    var index: Int
    var woId: String
    var items: Binding<[WO_Item]>
    var expandedIndex: Binding<Int?>
    var onDelete: ((Int) -> Void)?
    
    // Initialize with either pattern (simple or advanced)
    init(item: Binding<WO_Item>) {
        self._item = Binding(
            get: { item.wrappedValue },
            set: { item.wrappedValue = $0! }
        )
        self.index = 0
        self.woId = ""
        self.items = .constant([])
        self.expandedIndex = .constant(nil)
        self.onDelete = nil
    }
    
    init(index: Int, woId: String, items: Binding<[WO_Item]>, expandedIndex: Binding<Int?>, onDelete: ((Int) -> Void)?) {
        self._item = .constant(nil)
        self.index = index
        self.woId = woId
        self.items = items
        self.expandedIndex = expandedIndex
        self.onDelete = onDelete
    }
    
    // UI state
    @State private var internalIsExpanded = false
    @State private var selectedPickerItem: PhotosPickerItem? = nil
    
    // Computed properties for handling both modes
    private var isExpanded: Bool {
        if item == nil {
            return expandedIndex.wrappedValue == index
        } else {
            return internalIsExpanded
        }
    }
    
    private var currentItem: Binding<WO_Item> {
        if item == nil {
            // Using advanced mode with array binding
            return items[index]
        } else {
            // Using simple mode with direct binding
            return Binding(
                get: { self.item! },
                set: { self.item = $0 }
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(action: {
                if item == nil {
                    withAnimation {
                        expandedIndex.wrappedValue = isExpanded ? nil : index
                    }
                } else {
                    withAnimation {
                        internalIsExpanded.toggle()
                    }
                }
            }) {
                HStack {
                    Text(currentItem.wrappedValue.type.isEmpty ? "Unnamed Item" : currentItem.wrappedValue.type)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .padding()
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Type Field (only in advanced mode)
                    if item == nil {
                        TextField("Item Type", text: currentItem.type)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                    }
                    
                    // Image Upload Section
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(currentItem.wrappedValue.imageUrls, id: \.self) { url in
                                StorageAsyncImage(pathOrUrl: url)
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                            }
                            
                            PhotosPicker(selection: $selectedPickerItem, matching: .images) {
                                VStack {
                                    Image(systemName: "plus")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("Add Photo")
                                        .font(.caption)
                                }
                                .frame(width: 100, height: 100)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Delete Button (only in advanced mode)
                    if item == nil, let onDelete = onDelete {
                        Button(role: .destructive) {
                            onDelete(index)
                        } label: {
                            Label("Delete Item", systemImage: "trash")
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom)
            }
        }
        .onChange(of: selectedPickerItem) { _ in
            if selectedPickerItem != nil {
                processSelectedPhoto()
            }
        }
    }
    
    private func processSelectedPhoto() {
        guard let pickerItem = selectedPickerItem else { return }
        
        Task {
            do {
                let data = try await pickerItem.loadTransferable(type: Data.self)
                guard let data = data, let image = UIImage(data: data) else {
                    print("Failed to load image data")
                    await MainActor.run { selectedPickerItem = nil }
                    return
                }
                
                // Now we have the image, let's upload it
                await uploadImage(image)
            } catch {
                print("Error loading image: \(error)")
                await MainActor.run { selectedPickerItem = nil }
            }
        }
    }
    
    private func uploadImage(_ image: UIImage) async {
        // Using completion handler pattern from StorageManager but within Task
        await withCheckedContinuation { continuation in
            StorageManager.shared.uploadWOItemImageWithThumbnail(
                image: image,
                itemId: currentItem.wrappedValue.id
            ) { result in
                switch result {
                case .success(let (path, thumbPath)):
                    Task {
                        await MainActor.run {
                            var updatedItem = currentItem.wrappedValue
                            updatedItem.imageUrls.append(path)
                            updatedItem.thumbUrls.append(thumbPath)
                            updatedItem.localImages.append(image)
                            updatedItem.lastModified = Date()
                            
                            // Update the appropriate binding
                            if item == nil {
                                // Update in array (advanced mode)
                                items.wrappedValue[index] = updatedItem
                            } else {
                                // Update direct binding (simple mode)
                                item = updatedItem
                            }
                            
                            selectedPickerItem = nil
                        }
                    }
                case .failure(let error):
                    print("Upload failed: \(error.localizedDescription)")
                    Task {
                        await MainActor.run { selectedPickerItem = nil }
                    }
                }
                continuation.resume()
            }
        }
    }
}

struct StorageAsyncImage: View {
    let pathOrUrl: String
    @State private var resolvedURL: URL? = nil
    
    var body: some View {
        Group {
            if let resolvedURL {
                AsyncImage(url: resolvedURL) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
            } else {
                ProgressView()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        StorageImageResolver.resolve(pathOrUrl) { url in
            DispatchQueue.main.async {
                self.resolvedURL = url
            }
        }
    }
}

#Preview {
    WOItemAccordionRow(item: .constant(WO_Item.sample))
}
