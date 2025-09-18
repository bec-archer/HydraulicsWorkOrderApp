import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderCardView.swift
// Rebuilt according to ActiveWorkOrdersView_Layout_Spec_09092025.md
// Features: 2x2 thumbnail grid, indicator dots, theme integration
// ─────────────────────────────────────────────────────────────

class ImageResolverViewModel: ObservableObject {
    @Published var resolvedImageURLs: [URL] = []
    @Published var isResolving = false
    
    private let workOrder: WorkOrder
    private var cancellables = Set<AnyCancellable>()
    
    init(workOrder: WorkOrder) {
        self.workOrder = workOrder
        setupNotificationListener()
        
        // Resolve images immediately upon initialization
        resolveImageURLs()
    }
    
    private func setupNotificationListener() {
        // Listen for work order updates to refresh images
        NotificationCenter.default
            .publisher(for: .WorkOrderSaved)
            .sink { [weak self] _ in
                // Small delay to ensure database is updated
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.resolveImageURLs()
                }
            }
            .store(in: &cancellables)
    }
    
    func resolveImageURLs() {
        // Prevent multiple simultaneous resolutions
        if isResolving {
            print("⚠️ IMAGE: Already resolving for WO \(workOrder.workOrderNumber)")
            return
        }
        
        isResolving = true
        print("🔄 IMAGE: Resolving images for WO \(workOrder.workOrderNumber)")
        
        // Use the work order directly
        Task { @MainActor in
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
                print("  - item.thumbUrls.count: \(item.thumbUrls.count)")
                print("  - item.imageUrls.count: \(item.imageUrls.count)")
                if !item.thumbUrls.isEmpty {
                    print("  - First thumbUrl: \(item.thumbUrls[0])")
                }
                
                // Process thumbnail URLs first (preferred)
                for thumbUrl in item.thumbUrls {
                    if let url = URL(string: thumbUrl) {
                        if let imageId = extractImageId(from: thumbUrl) {
                            if !seenImageIds.contains(imageId) {
                                seenImageIds.insert(imageId)
                                candidateURLs.append(url)
                                currentRawPathsForWO.append(thumbUrl)
                                print("✅ ImageResolverViewModel: Added thumbUrl: \(thumbUrl)")
                            } else {
                                print("⚠️ ImageResolverViewModel: Duplicate image ID '\(imageId)' from thumbUrl: \(thumbUrl)")
                            }
                        } else {
                            print("❌ ImageResolverViewModel: Could not extract image ID from thumbUrl: \(thumbUrl)")
                        }
                    } else {
                        print("❌ ImageResolverViewModel: Invalid thumbUrl: \(thumbUrl)")
                    }
                }
                
                // Process full image URLs (fallback)
                for imageUrl in item.imageUrls {
                    if let url = URL(string: imageUrl) {
                        if let imageId = extractImageId(from: imageUrl) {
                            if !seenImageIds.contains(imageId) {
                                seenImageIds.insert(imageId)
                                candidateURLs.append(url)
                                currentRawPathsForWO.append(imageUrl)
                                print("✅ ImageResolverViewModel: Added imageUrl: \(imageUrl)")
                            } else {
                                print("⚠️ ImageResolverViewModel: Duplicate image ID '\(imageId)' from imageUrl: \(imageUrl)")
                            }
                        } else {
                            print("❌ ImageResolverViewModel: Could not extract image ID from imageUrl: \(imageUrl)")
                        }
                    } else {
                        print("❌ ImageResolverViewModel: Invalid imageUrl: \(imageUrl)")
                    }
                }
            }
            
            print("📊 ImageResolverViewModel: Final candidate count: \(candidateURLs.count)")
            print("📊 ImageResolverViewModel: Unique image IDs: \(seenImageIds.count)")
            
            // Limit to 4 images maximum
            let finalURLs = Array(candidateURLs.prefix(4))
            
            print("🔄 ImageResolverViewModel: No pending resolutions, immediate update: resolvedImageURLs = \(finalURLs.count) URLs")
            print("📋 Final URLs for WO \(workOrder.workOrderNumber) (immediate):")
            for (index, url) in finalURLs.enumerated() {
                print("  [\(index)]: \(url.absoluteString)")
            }
            self.resolvedImageURLs = finalURLs
            self.isResolving = false
        }
    }
}

struct WorkOrderCardView: View {
    let workOrder: WorkOrder
    let customerTag: String?
    let onTap: (() -> Void)?
    let imageAreaSize: CGFloat
    
    @State private var selectedImageURL: URL?
    
    // Wrapper to make URL identifiable for fullScreenCover
    private struct IdentifiableURL: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    init(workOrder: WorkOrder, imageAreaSize: CGFloat, customerTag: String? = nil, onTap: (() -> Void)? = nil) {
        self.workOrder = workOrder
        self.imageAreaSize = imageAreaSize
        self.customerTag = customerTag
        self.onTap = onTap
    }
    
    // Add a stable identifier to prevent unnecessary recreation
    private var stableId: String {
        workOrder.workOrderNumber
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail Grid (computed directly from WO_Items)
            WorkOrderCardThumbnailGrid(
                workOrder: workOrder,
                imageAreaSize: imageAreaSize,
                onImageLongPress: { imageURL in
                    print("🔍 DEBUG: Long-press detected on image: \(imageURL.absoluteString)")
                    print("🔍 DEBUG: Setting selectedImageURL to: \(imageURL.absoluteString)")
                    
                    // Set the selected image URL - this will trigger the fullScreenCover
                    selectedImageURL = imageURL
                    print("🔍 DEBUG: selectedImageURL is now: \(selectedImageURL?.absoluteString ?? "nil")")
                    print("🔍 DEBUG: FullScreenCover should now be presented")
                },
                onImageTap: onTap
            )
            
            // Main content
            WorkOrderCardContent(workOrder: workOrder, customerTag: customerTag, onTap: onTap)
        }
        .frame(minHeight: 400) // Increased card height to accommodate images and text
        .background(ThemeManager.shared.cardBackground)
        .cornerRadius(ThemeManager.shared.cardCornerRadius)
        .shadow(
            color: ThemeManager.shared.cardShadowColor.opacity(ThemeManager.shared.cardShadowOpacity * 2.5),
            radius: 12,
            x: 0,
            y: 6
        )
        .id(stableId)
        // Removed debug prints to improve performance
        // Removed debug prints to improve performance
        .fullScreenCover(item: Binding<IdentifiableURL?>(
            get: { 
                if let url = selectedImageURL {
                    return IdentifiableURL(url: url)
                }
                return nil
            },
            set: { _ in selectedImageURL = nil }
        )) { identifiableURL in
            FullScreenImageViewer(
                imageURL: identifiableURL.url,
                isPresented: Binding(
                    get: { selectedImageURL != nil },
                    set: { _ in selectedImageURL = nil }
                )
            )
            .onAppear {
                print("🔍 DEBUG: FullScreenCover presenting with URL: \(identifiableURL.url.absoluteString)")
            }
        }
    }
}

// MARK: - ImageViewerSheet
struct ImageViewerSheet: View {
    let imageURL: URL?
    @Binding var isPresented: Bool
    @State private var retryCount = 0
    
    var body: some View {
        if let imageURL = imageURL {
            FullScreenImageViewer(
                imageURL: imageURL,
                isPresented: $isPresented
            )
            .onAppear {
                print("🔍 DEBUG: ImageViewerSheet presenting with URL: \(imageURL.absoluteString)")
            }
        } else {
            VStack(spacing: 20) {
                Text("Loading image...")
                    .foregroundColor(.white)
                    .font(.title2)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Button("Close") {
                    isPresented = false
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .onAppear {
                print("🔍 DEBUG: ImageViewerSheet triggered but no imageURL")
                print("🔍 DEBUG: imageURL at sheet: \(imageURL?.absoluteString ?? "nil")")
                print("🔍 DEBUG: retryCount: \(retryCount)")
                
                // Retry after a brief delay if URL is not available
                if retryCount < 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        retryCount += 1
                        print("🔍 DEBUG: Retrying... attempt \(retryCount)")
                    }
                }
            }
        }
    }
}

struct WorkOrderCardContent: View {
    let workOrder: WorkOrder
    let customerTag: String?
    let onTap: (() -> Void)?
    
    @State private var showingPhoneActions = false
    
    private var itemSummaryLine: String {
        // First 3–4 items, "Type × Qty", joined with " • "
        let parts = workOrder.items.prefix(4).map { item in
            let t = item.type.isEmpty ? "Item" : item.type
            let q = 1  // schema currently lacks quantity; default to 1
            return "\(t) × \(q)"
        }
        return parts.joined(separator: " • ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // WO_Number with inline dots (timestamp moved to its own line below)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(workOrder.workOrderNumber)
                    .font(.system(size: 14.4, weight: .semibold)) // 80% of 18pt label font
                    .foregroundColor(ThemeManager.shared.textSecondary.opacity(0.5)) // 50% gray
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.95)
                
                // Inline dots (up to 4, one per WO_Item)
                HStack(spacing: 3) {
                    ForEach(Array(StatusMapping.itemStatusesWithColor(for: workOrder).enumerated()), id: \.offset) { _, itemStatus in
                        IndicatorDot(color: itemStatus.color, size: 6)
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // Customer name with emoji and flag — primary emphasis
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(workOrder.customerName)
                    .font(ThemeManager.shared.labelFont)       // 18pt semibold per theme
                    .foregroundColor(ThemeManager.shared.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if let emoji = workOrder.customerEmojiTag {
                    Text(emoji).font(.title3)
                }
                
                Spacer(minLength: 0)
                
                if workOrder.flagged {
                    Image(systemName: "flag.fill")
                        .foregroundColor(ThemeManager.shared.linkColor)
                        .font(.caption)
                }
            }
            
            // Phone number (tappable with long-press for actions)
            PhoneNumberView(
                phoneNumber: workOrder.customerPhone,
                onTap: callCustomer,
                onLongPress: { showingPhoneActions = true }
            )

            // Timestamp (own line, small, secondary)
            Text(timeAgoString)
                .font(.caption)
                .foregroundColor(ThemeManager.shared.textSecondary.opacity(0.5)) // 50% gray
                .lineLimit(1)
            
            // Type × Qty summary (muted footer, single line)
            if !itemSummaryLine.isEmpty {
                Text(itemSummaryLine)
                    .font(.caption2)
                    .foregroundColor(ThemeManager.shared.textSecondary.opacity(0.5)) // 50% gray
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)   // slightly denser body
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .sheet(isPresented: $showingPhoneActions) {
            PhoneActionSheet(phoneNumber: workOrder.customerPhone, customerName: workOrder.customerName)
        }
    }
    
    private var timeAgoString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: workOrder.timestamp)
    }
    
    private func callCustomer() {
        let phoneNumber = workOrder.customerPhone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if let url = URL(string: "tel:\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - PhoneNumberView
struct PhoneNumberView: View {
    let phoneNumber: String
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var isLongPressing = false
    @State private var longPressTimer: Timer?
    
    var body: some View {
        Text(phoneNumber.formattedPhoneNumber)
            .font(ThemeManager.shared.labelFont)
            .fontWeight(.bold)
            .underline()
            .foregroundColor(ThemeManager.shared.linkColor)
            .lineLimit(1)
            .onTapGesture {
                if !isLongPressing {
                    onTap()
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                isLongPressing = true
                onLongPress()
            } onPressingChanged: { pressing in
                if pressing {
                    isLongPressing = false
                }
            }
    }
}

struct WorkOrderCardThumbnailGrid: View {
    let workOrder: WorkOrder
    let imageAreaSize: CGFloat
    let onImageLongPress: (URL) -> Void
    let onImageTap: (() -> Void)?

    // Layout dimensions
    private let spacing: CGFloat = 6             // tighter gutters per Notes style
    
    // Helper function to determine if an individual item is complete
    private func isItemComplete(_ item: WO_Item) -> Bool {
        let resolvedStatus = StatusMapping.resolvedStatus(for: item)
        return resolvedStatus.lowercased() == "complete" || resolvedStatus.lowercased() == "completed"
    }

    var body: some View {
        let totalItems = workOrder.items.count
        let displayCount = min(totalItems, 4)
        let imageInfos: [(url: URL?, item: WO_Item)] = Array(workOrder.items.prefix(displayCount)).map { item in
            (firstImageURL(for: item), item)
        }

        // Consistent image area size for all card types
        VStack(spacing: spacing) {
            if displayCount == 1 {
                // 1 item: ONE perfect square image - fills the entire image area
                if let info = imageInfos.first {
                    SquareThumb(
                        url: info.url,
                        itemStatus: StatusMapping.ItemStatus(for: info.item),
                        typeQtyLabel: "\(info.item.type.isEmpty ? "Item" : info.item.type) × 1",
                        onLongPress: onImageLongPress,
                        onTap: onImageTap,
                        isItemComplete: isItemComplete(info.item)
                    )
                    .frame(width: imageAreaSize, height: imageAreaSize) // Use consistent size
                }
            } else if displayCount == 2 {
                // 2 items: TWO full-width rectangular images stacked vertically
                // Each image gets half the image area height minus spacing
                let imageHeight = (imageAreaSize - spacing) / 2
                VStack(spacing: spacing) {
                    ForEach(Array(imageInfos.enumerated()), id: \.offset) { _, info in
                        FullWidthThumb(
                            url: info.url,
                            height: imageHeight,
                            itemStatus: StatusMapping.ItemStatus(for: info.item),
                            typeQtyLabel: "\(info.item.type.isEmpty ? "Item" : info.item.type) × 1",
                            onLongPress: onImageLongPress,
                            onTap: onImageTap,
                            isItemComplete: isItemComplete(info.item)
                        )
                    }
                }
            } else {
                // 3–4 items: 2×2 grid of square images
                // Each cell gets half the image area size minus spacing
                let cellSize = (imageAreaSize - spacing) / 2
                LazyVGrid(columns: [
                    GridItem(.fixed(cellSize), spacing: spacing),
                    GridItem(.fixed(cellSize), spacing: spacing)
                ], spacing: spacing) {
                    ForEach(Array(imageInfos.enumerated()), id: \.offset) { idx, info in
                        GridThumb(
                            url: info.url,
                            size: cellSize,
                            itemStatus: StatusMapping.ItemStatus(for: info.item),
                            showPlusBadge: (idx == 3 && totalItems > 4) ? (totalItems - 3) : nil,
                            typeQtyLabel: "\(info.item.type.isEmpty ? "Item" : info.item.type) × 1",
                            onLongPress: onImageLongPress,
                            onTap: onImageTap,
                            isItemComplete: isItemComplete(info.item)
                        )
                    }
                }
            }
        }
        .frame(width: imageAreaSize, height: imageAreaSize) // Consistent square image area
        .padding(.horizontal, 16)
        .padding(.top, 8)     // tighter top margin
        // Removed debug prints to improve performance
    }

    // Always use a non-distorted source for UI cropping.
    // Prefer ORIGINAL image (imageUrls[0]) and only fall back to thumb if missing.
    private func firstImageURL(for item: WO_Item) -> URL? {
        if let first = item.imageUrls.first, let u = URL(string: first) {
            return u
        }
        if let first = item.thumbUrls.first, let u = URL(string: first) {
            return u
        }
        return nil
    }
}

// MARK: - Thumb Variants

private struct SquareThumb: View {
    let url: URL?
    let itemStatus: StatusMapping.ItemStatus
    var typeQtyLabel: String = ""
    let onLongPress: (URL) -> Void
    let onTap: (() -> Void)?
    let isItemComplete: Bool  // NEW: Add individual item completion status

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(ThemeManager.shared.border.opacity(0.25))
                            .overlay(ProgressView().scaleEffect(0.9))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Rectangle().fill(Color.red.opacity(0.25)).overlay(Text("❌"))
                    @unknown default:
                        Rectangle().fill(ThemeManager.shared.border.opacity(0.25))
                    }
                }
                .id(url?.absoluteString) // Add stable ID to prevent unnecessary reloads
                .frame(width: geo.size.width, height: geo.size.width) // ⬅️ fixed square frame (like WorkOrderDetailView)
                .clipped()
                .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)

                // Green "Complete" banner (diagonal across top-left corner)
                if isItemComplete {
                    VStack {
                        HStack {
                            Text("COMPLETE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                )
                                .rotationEffect(.degrees(-15))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                    // Removed debug print to improve performance
                }

                // Indicator dot (inside)
                OverlayDot(color: itemStatus.color, size: 10)
                    .padding(6)

                // Bottom-left "Type × Qty"
                VStack {
                    Spacer()
                    HStack {
                        Text(typeQtyLabel)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(6)
                            .padding(6)
                        Spacer()
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit) // ⬅️ reserve square space in the card
        .onTapGesture {
            onTap?()
        }
        .onLongPressGesture {
            if let imageURL = url {
                onLongPress(imageURL)
            }
        }
    }
}

private struct FullWidthThumb: View {
    let url: URL?
    let height: CGFloat
    let itemStatus: StatusMapping.ItemStatus
    var typeQtyLabel: String = ""
    let onLongPress: (URL) -> Void
    let onTap: (() -> Void)?
    let isItemComplete: Bool  // NEW: Add individual item completion status

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(ThemeManager.shared.border.opacity(0.25))
                        .overlay(ProgressView().scaleEffect(0.9))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .overlay(Text("❌").font(.title))
                @unknown default:
                    Rectangle()
                        .fill(ThemeManager.shared.border.opacity(0.25))
                        .overlay(Text("?").font(.title))
                }
            }
            .id(url?.absoluteString) // Add stable ID to prevent unnecessary reloads
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(10)

            // Green "Complete" banner (diagonal across top-left corner)
            if isItemComplete {
                VStack {
                    HStack {
                        Text("COMPLETE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                            )
                            .rotationEffect(.degrees(-15))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }

            // Indicator dot (top-right, inside the image)
            OverlayDot(color: itemStatus.color, size: 10)
                .padding(6)

            // Bottom-left "Type × Qty" label
            VStack {
                Spacer()
                HStack {
                    Text(typeQtyLabel)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(6)
                        .padding(6)
                    Spacer()
                }
            }
        }
        .onTapGesture {
            onTap?()
        }
        .onLongPressGesture {
            if let imageURL = url {
                onLongPress(imageURL)
            }
        }
    }
}

private struct GridThumb: View {
    let url: URL?
    let size: CGFloat
    let itemStatus: StatusMapping.ItemStatus
    /// If not nil, show a "+Qty" badge centered (used when total items > 4)
    let showPlusBadge: Int?
    var typeQtyLabel: String = ""
    let onLongPress: (URL) -> Void
    let onTap: (() -> Void)?
    let isItemComplete: Bool  // NEW: Add individual item completion status

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(ThemeManager.shared.border.opacity(0.25))
                        .overlay(ProgressView().scaleEffect(0.8))
                        .onAppear {
                            print("🔍 DEBUG: GridThumb AsyncImage EMPTY for URL: \(url?.absoluteString ?? "nil")")
                        }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .onAppear {
                            print("✅ DEBUG: GridThumb AsyncImage SUCCESS for URL: \(url?.absoluteString ?? "nil")")
                        }
                case .failure(let error):
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .overlay(Text("❌").font(.title))
                        .onAppear {
                            print("❌ DEBUG: GridThumb AsyncImage FAILED for URL: \(url?.absoluteString ?? "nil") - Error: \(error)")
                        }
                @unknown default:
                    Rectangle()
                        .fill(ThemeManager.shared.border.opacity(0.25))
                        .overlay(Text("?").font(.title))
                        .onAppear {
                            print("⚠️ DEBUG: GridThumb AsyncImage UNKNOWN for URL: \(url?.absoluteString ?? "nil")")
                        }
                }
            }
            .frame(width: size, height: size)
            .clipped()
            .cornerRadius(10)

            // Green "Complete" banner (diagonal across top-left corner)
            if isItemComplete {
                VStack {
                    HStack {
                        Text("COMPLETE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                            )
                            .rotationEffect(.degrees(-15))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(6)
            }

            // "+Qty" badge for overflow (centered)
            if let overflow = showPlusBadge, overflow > 0 {
                ZStack {
                    Color.black.opacity(0.6)
                        .frame(width: size, height: size)
                        .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
                    Text("+\(overflow)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }

            // Indicator dot (top-right, inside the image)
            OverlayDot(color: itemStatus.color, size: 10)
                .padding(6)

            // Bottom-left "Type × Qty" label
            VStack {
                Spacer()
                HStack {
                    Text(typeQtyLabel)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(6)
                        .padding(6)
                    Spacer()
                }
            }
        }
        .onAppear {
            print("🔍 DEBUG: GridThumb appeared for URL: \(url?.absoluteString ?? "nil"), showPlusBadge: \(showPlusBadge ?? 0)")
        }
        .onTapGesture {
            onTap?()
        }
        .onLongPressGesture {
            print("🔍 DEBUG: GridThumb long-press gesture triggered")
            if let imageURL = url {
                print("🔍 DEBUG: GridThumb calling onLongPress with URL: \(imageURL.absoluteString)")
                onLongPress(imageURL)
            } else {
                print("🔍 DEBUG: GridThumb long-press but no URL available")
            }
        }
    }
}


// MARK: - Legacy Components (kept for compatibility)
struct WorkOrderDetailHeader: View {
    let workOrder: WorkOrder
    let customerTag: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Work order number and status
            HStack {
                Text(workOrder.workOrderNumber)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                StatusBadge(status: workOrder.status)
            }
            
            // Customer info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let emoji = workOrder.customerEmojiTag {
                        Text(emoji)
                            .font(.title)
                    }
                    
                    Text(workOrder.customerName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                if let company = workOrder.customerCompany {
                    Text(company)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(workOrder.customerPhone.formattedPhoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct WorkOrderContactSheet: View {
    let workOrder: WorkOrder
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose how to contact \(workOrder.customerName)")
            }
            .navigationTitle("Contact Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let sampleWorkOrder = WorkOrder(
        id: UUID().uuidString,
        createdBy: "test_user",
        customerId: UUID().uuidString,
        customerName: "John Doe",
        customerCompany: "ACME Corp",
        customerEmail: "john@acme.com",
        customerTaxExempt: false,
        customerPhone: "555-1234",
        customerEmojiTag: "🏢",
        workOrderType: "Repair",
        primaryImageURL: nil,
        timestamp: Date(),
        status: "In Progress",
        workOrderNumber: "WO-2024-001",
        flagged: false,
        assetTagId: nil,
        estimatedCost: "150.0",
        finalCost: nil,
        dropdowns: [:],
        dropdownSchemaVersion: 1,
        lastModified: Date(),
        lastModifiedBy: "test_user",
        tagBypassReason: nil,
        isDeleted: false,
        syncStatus: "synced",
        lastSyncDate: Date(),
        notes: [],
        items: []
    )
    
    WorkOrderCardView(workOrder: sampleWorkOrder, imageAreaSize: 200)
        .padding()
}