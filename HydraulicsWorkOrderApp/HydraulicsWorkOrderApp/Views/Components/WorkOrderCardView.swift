//
//  WorkOrderCardView.swift
//  HydraulicsWorkOrderApp
//
//  Restored after accidental overwrite. This file defines the card used
//  in ActiveWorkOrdersView. It intentionally relies ONLY on WorkOrder.imageURL
//  for the preview. The uploader now sets that immediately after first image upload.
//
//  Created by Bec Archer on 8/8/25.
//

import SwiftUI
import FirebaseFirestore
import Combine

// MARK: - ImageResolverViewModel
class ImageResolverViewModel: ObservableObject {
    @Published var resolvedImageURLs: [URL] = []
    private var cancellables = Set<AnyCancellable>()
    private let workOrderNumber: String
    private var isResolving = false
    private var lastResolvedRawPaths: [String] = []
    
    init(workOrderNumber: String) {
        self.workOrderNumber = workOrderNumber
        setupNotificationListener()
        // Resolve images immediately upon initialization
        resolveImageURLs()
    }
    
    private func setupNotificationListener() {
        NotificationCenter.default.publisher(for: .WorkOrderSaved)
            .sink { [weak self] notification in
                if let woNumber = notification.userInfo?["WO_Number"] as? String,
                   woNumber == self?.workOrderNumber {
                    print("🔄 ImageResolverViewModel: Received WorkOrderSaved notification for WO \(woNumber)")
                    self?.resolveImageURLs()
                }
            }
            .store(in: &cancellables)
    }
    
    func resolveImageURLs() {
        // Prevent multiple simultaneous resolutions
        if isResolving {
            print("⚠️ IMAGE: Already resolving for WO \(workOrderNumber)")
            return
        }
        
        isResolving = true
        print("🔄 IMAGE: Resolving images for WO \(workOrderNumber)")
        
        // Get the work order from cache
        guard let workOrder = WorkOrdersDatabase.shared.workOrders.first(where: { $0.WO_Number == workOrderNumber }) else {
            print("❌ IMAGE: WorkOrder not found for WO \(workOrderNumber)")
            isResolving = false
            return
        }
        
        print("✅ IMAGE: Found WO with \(workOrder.items.count) items")
        
        var candidateURLs: [URL] = []
        var currentRawPathsForWO: [String] = []
        
        // Helper function to extract the base image identifier from a URL
        func extractImageId(from urlString: String) -> String? {
            // Extract just the filename without the path and query parameters
            // Example: "intake/BC004DA3-5051-4316-B8AC-F4E44A108832/702678B4-168A-4796-960E-1CB16A638D15/thumbs/20250825_133353_453.jpg"
            // We want: "20250825_133353_453.jpg"
            
            // First, remove query parameters
            let urlWithoutQuery = urlString.components(separatedBy: "?").first ?? urlString
            
            // URL-decode the path
            let decodedPath = urlWithoutQuery.removingPercentEncoding ?? urlWithoutQuery
            
            // Split by "/" and get the last component (filename)
            let components = decodedPath.components(separatedBy: "/")
            guard let filename = components.last else { return nil }
            
            print("🔍 ImageResolverViewModel: Extracted image ID '\(filename)' from '\(urlString)'")
            return filename
        }
        
        var seenImageIds = Set<String>()
        
        // Process each item's images
        for (itemIndex, item) in workOrder.items.enumerated() {
            print("📸 ImageResolverViewModel: Processing item \(itemIndex + 1)/\(workOrder.items.count) - \(item.type)")
            
            // Only add the first image from this item (prefer thumbnail, then full image)
            var firstImageAdded = false
            
            // First try to add a thumbnail
            for path in item.thumbUrls {
                if !firstImageAdded, let url = URL(string: path), let imageId = extractImageId(from: path) {
                    if !seenImageIds.contains(imageId) {
                        candidateURLs.append(url)
                        currentRawPathsForWO.append(path) // Store the raw path
                        seenImageIds.insert(imageId)
                        firstImageAdded = true
                        print("✅ ImageResolverViewModel: Added first thumbnail for image ID: \(imageId)")
                        break // Only add the first thumbnail
                    } else {
                        print("⚠️ ImageResolverViewModel: Skipped duplicate thumbnail for image ID: \(imageId)")
                    }
                }
            }
            
            // If no thumbnail was added, try to add a full image
            if !firstImageAdded {
                for path in item.imageUrls {
                    if !firstImageAdded, let url = URL(string: path), let imageId = extractImageId(from: path) {
                        if !seenImageIds.contains(imageId) {
                            candidateURLs.append(url)
                            currentRawPathsForWO.append(path) // Store the raw path
                            seenImageIds.insert(imageId)
                            firstImageAdded = true
                            print("✅ ImageResolverViewModel: Added first full image for image ID: \(imageId)")
                            break // Only add the first full image
                        } else {
                            print("⚠️ ImageResolverViewModel: Skipped duplicate full image for image ID: \(imageId)")
                        }
                    }
                }
            }
            
            if !firstImageAdded {
                print("⚠️ ImageResolverViewModel: No images added for item \(item.type)")
            }
            
            print("🔗 ImageResolverViewModel: Found \(candidateURLs.count) candidate URLs for item \(itemIndex + 1)")
        }
        
        // --- NEW DEDUPLICATION CHECK ---
        // If the raw paths haven't changed, no need to re-resolve or update
        if currentRawPathsForWO == lastResolvedRawPaths {
            print("ℹ️ ImageResolverViewModel: Raw image paths for WO \(workOrderNumber) are unchanged, skipping re-resolution.")
            isResolving = false
            return
        }
        
        // Update last resolved paths
        lastResolvedRawPaths = currentRawPathsForWO
        print("🔄 ImageResolverViewModel: Raw image paths changed, proceeding with re-resolution")
        
        // Clear existing URLs to prevent accumulation (only if paths changed)
        self.resolvedImageURLs = []
        
        var newURLs: [URL] = []
        var seenURLs = Set<String>()
        var pendingResolutions = 0
        
        // Process candidate URLs
        for (urlIndex, candidateURL) in candidateURLs.enumerated() {
            print("🌐 ImageResolverViewModel: Processing URL \(urlIndex + 1)/\(candidateURLs.count): \(candidateURL.absoluteString)")
            
            if candidateURL.absoluteString.lowercased().hasPrefix("http") {
                // Direct HTTPS URL - add immediately
                print("✅ ImageResolverViewModel: Direct HTTPS URL found, adding immediately")
                if !seenURLs.contains(candidateURL.absoluteString) {
                    newURLs.append(candidateURL)
                    seenURLs.insert(candidateURL.absoluteString)
                    print("✅ ImageResolverViewModel: Added unique URL: \(candidateURL.absoluteString)")
                } else {
                    print("⚠️ ImageResolverViewModel: Skipped duplicate URL: \(candidateURL.absoluteString)")
                }
            } else {
                // Need to resolve through Firebase Storage
                print("🔄 ImageResolverViewModel: Resolving through Firebase Storage")
                pendingResolutions += 1
                
                StorageImageResolver.resolve(candidateURL.absoluteString) { resolvedURL in
                    DispatchQueue.main.async {
                        pendingResolutions -= 1
                        
                        if let resolvedURL = resolvedURL {
                            print("✅ ImageResolverViewModel: Successfully resolved to \(resolvedURL.absoluteString)")
                            if !seenURLs.contains(resolvedURL.absoluteString) {
                                newURLs.append(resolvedURL)
                                seenURLs.insert(resolvedURL.absoluteString)
                                print("✅ ImageResolverViewModel: Added unique resolved URL: \(resolvedURL.absoluteString)")
                            } else {
                                print("⚠️ ImageResolverViewModel: Skipped duplicate resolved URL: \(resolvedURL.absoluteString)")
                            }
                        } else {
                            print("❌ ImageResolverViewModel: Failed to resolve \(candidateURL.absoluteString)")
                        }
                        
                        // If all resolutions are complete, update the published property
                        if pendingResolutions == 0 {
                            print("🔄 ImageResolverViewModel: All resolutions complete, updating resolvedImageURLs with \(newURLs.count) unique URLs")
                            print("📋 Final URLs for WO \(self.workOrderNumber):")
                            for (index, url) in newURLs.enumerated() {
                                print("  [\(index)]: \(url.absoluteString)")
                            }
                            self.resolvedImageURLs = newURLs
                            self.isResolving = false
                        }
                    }
                }
            }
        }
        
        // If no pending resolutions, update immediately
        if pendingResolutions == 0 {
            print("🔄 ImageResolverViewModel: No pending resolutions, immediate update: resolvedImageURLs = \(newURLs.count) URLs")
            print("📋 Final URLs for WO \(workOrderNumber) (immediate):")
            for (index, url) in newURLs.enumerated() {
                print("  [\(index)]: \(url.absoluteString)")
            }
            self.resolvedImageURLs = newURLs
            self.isResolving = false
        }
    }
}

// MARK: - WorkOrderCardView
struct WorkOrderCardView: View {
    let workOrder: WorkOrder
    @StateObject private var imageResolver: ImageResolverViewModel
    @State private var showingFullScreenImage = false
    @State private var selectedImageIndex = 0
    @State private var isPressed: Bool = false

    private let thumbHeight: CGFloat = 200 // Made square by matching width

    init(workOrder: WorkOrder) {
        self.workOrder = workOrder
        self._imageResolver = StateObject(wrappedValue: ImageResolverViewModel(workOrderNumber: workOrder.WO_Number))
    }
    
    // Add a stable identifier to prevent unnecessary recreation
    private var stableId: String {
        workOrder.WO_Number
    }

    var body: some View {
        coreContent
            .background(eventBinder) // lifecycle & notifications separated
            .modifier(CardChrome(isPressed: $isPressed)) // visual chrome
            .modifier(CardPressGesture(isPressed: $isPressed)) // press gesture
            .sheet(isPresented: $showingFullScreenImage) {
                if !imageResolver.resolvedImageURLs.isEmpty && selectedImageIndex < imageResolver.resolvedImageURLs.count {
                    FullScreenImageViewer(
                        imageURL: imageResolver.resolvedImageURLs[selectedImageIndex],
                        isPresented: $showingFullScreenImage
                    )
                }
            }
    }

    // ───── Core Content (extracted) ─────
    private var coreContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardThumbnail
            InfoBlockView(workOrder: workOrder)
        }
        .id(stableId) // Use stable ID instead of lastModified to prevent recreation
    }
    // END

    // ───── Event Binder (onAppear/onChange/tasks/notifications) ─────
    private var eventBinder: some View {
        Color.clear
            .onAppear {
                // Debug info only when needed
            }
            .onDisappear { isPressed = false }
    }
    // END

    private var placeholderImage: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            )
    }

     // ───── Card Thumbnail (extracted to aid type‑checker) ─────
     private var cardThumbnail: AnyView {
         AnyView(
             GridThumbnailView(
                resolvedImageURLs: imageResolver.resolvedImageURLs,
                 thumbHeight: thumbHeight,
                 placeholderImage: AnyView(placeholderImage),
                workOrder: workOrder,
                onImageLongPress: { index in
                    selectedImageIndex = index
                    showingFullScreenImage = true
                }
             )
             .frame(height: thumbHeight)
             .clipShape(RoundedRectangle(cornerRadius: 12))
             .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
         )
     }
     // END

  // ───── CardChrome ViewModifier (visual styling only) ─────
  private struct CardChrome: ViewModifier {
      @Binding var isPressed: Bool
      func body(content: Content) -> some View {
          content
              .padding()
              .background(Color.white)
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
              .overlay(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(isPressed ? Color(.systemGray2) : Color.clear, lineWidth: isPressed ? 2 : 0)
              )
              .shadow(color: Color.black.opacity(isPressed ? 0.18 : 0.12), radius: isPressed ? 8 : 6, x: 0, y: isPressed ? 4 : 3)
              .scaleEffect(isPressed ? 0.98 : 1.0)
              .animation(.spring(response: 0.26, dampingFraction: 0.82, blendDuration: 0.2), value: isPressed)
              .padding(.vertical, 6)
              .padding(.horizontal, 6)
              .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
  }
  // END

  // ───── CardPressGesture ViewModifier (gesture only) ─────
  private struct CardPressGesture: ViewModifier {
      @Binding var isPressed: Bool
      func body(content: Content) -> some View {
          content.simultaneousGesture(
              DragGesture(minimumDistance: 0)
                  .onChanged { _ in
                      if !isPressed { isPressed = true }
                  }
                  .onEnded { _ in
                      isPressed = false
                  }
          )
      }
  }
  // END
}

// ───── GridThumbnailView Subview ─────
struct GridThumbnailView: View {
    let resolvedImageURLs: [URL]
    let thumbHeight: CGFloat
    let placeholderImage: AnyView
    let workOrder: WorkOrder // Add reference to work order for status
    let onImageLongPress: (Int) -> Void
    
    // Helper to get status color
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "checked in": return UIConstants.StatusColors.checkedIn
        case "disassembly": return UIConstants.StatusColors.disassembly
        case "in progress": return UIConstants.StatusColors.inProgress
        case "test failed": return UIConstants.StatusColors.testFailed
        case "completed": return UIConstants.StatusColors.completed
        case "closed": return UIConstants.StatusColors.closed
        default: return UIConstants.StatusColors.fallback
        }
    }
    
    private var imageSize: CGSize {
        CGSize(width: thumbHeight, height: thumbHeight)
    }
    
    private var halfImageSize: CGSize {
        CGSize(width: (thumbHeight - 4) / 2, height: (thumbHeight - 4) / 2)
    }

    var body: some View {
        if resolvedImageURLs.isEmpty {
            placeholderImage
                .aspectRatio(1, contentMode: .fit)
                .frame(height: thumbHeight)
        } else if resolvedImageURLs.count == 1 {
            // Single image - square aspect ratio
            AsyncImage(url: resolvedImageURLs[0]) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: thumbHeight, height: thumbHeight)
                case .success(let image):
                    image
                                                            .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: thumbHeight, height: thumbHeight)
                                    .clipped()
                                    .overlay(alignment: .topTrailing) {
                                        // Show status for the first item that matches this image URL
                                        if let item = workOrder.items.first(where: { item in
                                item.imageUrls.contains(where: { $0 == resolvedImageURLs[0].absoluteString }) ||
                                item.thumbUrls.contains(where: { $0 == resolvedImageURLs[0].absoluteString })
                                        }) {
                                            let status = item.statusHistory.last?.status ?? "Checked In"
                                            Circle()
                                                .fill(statusColor(for: status))
                                                .frame(width: 12, height: 12)
                                                .padding(8)
                                        }
                                    }
                        .onLongPressGesture {
                            onImageLongPress(0)
                        }
                case .failure(_):
                    ProgressView()
                        .frame(width: thumbHeight, height: thumbHeight)
                @unknown default:
                    ProgressView()
                        .frame(width: thumbHeight, height: thumbHeight)
                }
            }
        } else {
            // Multiple images - grid layout
            if resolvedImageURLs.count == 2 {
                // 2 images stacked vertically
                VStack(spacing: 8) {
                    ForEach(Array(resolvedImageURLs.enumerated()), id: \.offset) { index, url in
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: (thumbHeight - 8) / 2)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(alignment: .topTrailing) {
                                        // Show status for the first item that matches this image URL
                                        if let item = workOrder.items.first(where: { item in
                                            item.imageUrls.contains(where: { $0 == url.absoluteString }) ||
                                            item.thumbUrls.contains(where: { $0 == url.absoluteString })
                                        }) {
                                            let status = item.statusHistory.last?.status ?? "Checked In"
                                            Circle()
                                                .fill(statusColor(for: status))
                                                .frame(width: 10, height: 10) // Slightly smaller for the grid
                                                .padding(6)
                                        }
                                    }
                                .onLongPressGesture {
                                    onImageLongPress(index)
                                    }
                            } placeholder: {
                                ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: (thumbHeight - 8) / 2)
                                .cornerRadius(8)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                // 3+ images in 2x2 grid
                LazyVGrid(columns: [
                    GridItem(.fixed(thumbHeight / 2), spacing: 4),
                    GridItem(.fixed(thumbHeight / 2), spacing: 4)
                ], spacing: 4) {
                    ForEach(Array(resolvedImageURLs.prefix(4).enumerated()), id: \.offset) { index, url in
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: (thumbHeight - 4) / 2, height: (thumbHeight - 4) / 2)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(alignment: .topTrailing) {
                                        // Show status for the first item that matches this image URL
                                        if let item = workOrder.items.first(where: { item in
                                            item.imageUrls.contains(where: { $0 == url.absoluteString }) ||
                                            item.thumbUrls.contains(where: { $0 == url.absoluteString })
                                        }) {
                                            let status = item.statusHistory.last?.status ?? "Checked In"
                                            Circle()
                                                .fill(statusColor(for: status))
                                                .frame(width: 8, height: 8) // Even smaller for the 2x2 grid
                                                .padding(4)
                                        }
                                    }
                                .onLongPressGesture {
                                    onImageLongPress(index)
                                    }
                            } placeholder: {
                                ProgressView()
                                .frame(width: (thumbHeight - 4) / 2, height: (thumbHeight - 4) / 2)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
}

// ───── InfoBlockView Subview ─────
struct InfoBlockView: View {
    let workOrder: WorkOrder
    @Environment(\.openURL) private var openURL
    @State private var showingPhoneActions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workOrder.WO_Number)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if workOrder.flagged {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Status dots for each item
                HStack(spacing: 4) {
                    ForEach(workOrder.items.indices, id: \.self) { index in
                        let item = workOrder.items[index]
                        let status = item.statusHistory.last?.status ?? "Checked In"
                        Circle()
                            .fill(statusColor(for: status))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(workOrder.customerName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let company = workOrder.customerCompany, !company.isEmpty {
                    Text(company)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    #if DEBUG
                    let _ = print("🔍 WorkOrder \(workOrder.WO_Number) - customerCompany: '\(workOrder.customerCompany ?? "nil")'")
                    #endif
                }

                    Text(workOrder.customerPhone)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#FFC500"))
                        .underline()
                        .lineLimit(1)
                        .truncationMode(.middle)
                    .onLongPressGesture {
                        showingPhoneActions = true
                }
            }

            Text(workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            // Display item types at bottom with dot separators
            let itemTypes = getItemTypeCounts()
            if !itemTypes.isEmpty {
                let itemTypeText = itemTypes.map { "\($0.type) × \($0.count)" }.joined(separator: " • ")
                    Text(itemTypeText)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
            }
        }
        .confirmationDialog("Contact \(workOrder.customerName)", isPresented: $showingPhoneActions) {
            Button("Call \(workOrder.customerPhone)") {
                let phoneNumber = digitsOnly(workOrder.customerPhone)
                let telURL = URL(string: "tel://\(phoneNumber)")
                
                #if DEBUG
                print("📞 Phone call selected - Number: \(phoneNumber)")
                print("📞 Phone call selected - URL: \(telURL?.absoluteString ?? "invalid URL")")
                #endif
                
                if let telURL = telURL {
                    openURL(telURL) { success in
                        if !success {
                            #if DEBUG
                            print("❌ Failed to open phone URL - this is expected in Simulator")
                            #endif
                            
                            // Copy number to clipboard as fallback
                            UIPasteboard.general.string = phoneNumber
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                    }
                }
            }
            
            Button("Text \(workOrder.customerPhone)") {
                let phoneNumber = digitsOnly(workOrder.customerPhone)
                let smsURL = URL(string: "sms://\(phoneNumber)")
                
                #if DEBUG
                print("💬 Text selected - Number: \(phoneNumber)")
                print("💬 Text selected - URL: \(smsURL?.absoluteString ?? "invalid URL")")
                #endif
                
                if let smsURL = smsURL {
                    openURL(smsURL) { success in
                        if !success {
                            #if DEBUG
                            print("❌ Failed to open SMS URL - this is expected in Simulator")
                            #endif
                            
                            // Copy number to clipboard as fallback
                            UIPasteboard.general.string = phoneNumber
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                    }
                }
            }
            
            Button("Copy Number", role: .none) {
                let phoneNumber = digitsOnly(workOrder.customerPhone)
                UIPasteboard.general.string = phoneNumber
                
                #if DEBUG
                print("📋 Phone number copied to clipboard: \(phoneNumber)")
                #endif
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how to contact \(workOrder.customerName)")
        }
    }
    
    // Helper function to get item type counts
    private func getItemTypeCounts() -> [ItemTypeCount] {
        var typeCounts: [String: Int] = [:]
        
        #if DEBUG
        print("🔍 WorkOrder \(workOrder.WO_Number) has \(workOrder.items.count) items")
        #endif
        
        for item in workOrder.items {
            let type = item.type.isEmpty ? "Item" : item.type
            typeCounts[type, default: 0] += 1
            #if DEBUG
            print("  - Item type: '\(type)'")
            #endif
        }
        
        let result = typeCounts.map { ItemTypeCount(type: $0.key, count: $0.value) }
            .sorted { $0.type < $1.type }
        
        #if DEBUG
        print("  Result: \(result.map { "\($0.type) x \($0.count)" }.joined(separator: ", "))")
        #endif
        
        return result
    }
    
    private struct ItemTypeCount {
        let type: String
        let count: Int
    }

    private func digitsOnly(_ s: String) -> String { s.filter(\.isNumber) }
    
    // Helper to get status color
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "checked in": return UIConstants.StatusColors.checkedIn
        case "disassembly": return UIConstants.StatusColors.disassembly
        case "in progress": return UIConstants.StatusColors.inProgress
        case "test failed": return UIConstants.StatusColors.testFailed
        case "completed": return UIConstants.StatusColors.completed
        case "closed": return UIConstants.StatusColors.closed
        default: return UIConstants.StatusColors.fallback
        }
    }
}

// MARK: - Preview
struct WorkOrderCardView_Previews: PreviewProvider {
    static var previews: some View {
    WorkOrderCardView(workOrder: WorkOrder.sample)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
