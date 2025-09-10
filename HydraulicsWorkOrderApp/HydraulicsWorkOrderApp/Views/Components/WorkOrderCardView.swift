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
    
    init(workOrder: WorkOrder, customerTag: String? = nil) {
        self.workOrder = workOrder
        self.customerTag = customerTag
    }
    
    // Add a stable identifier to prevent unnecessary recreation
    private var stableId: String {
        workOrder.workOrderNumber
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail Grid (computed directly from WO_Items)
            WorkOrderCardThumbnailGrid(
                workOrder: workOrder
            )
            
            // Main content
            WorkOrderCardContent(workOrder: workOrder, customerTag: customerTag)
        }
        .background(ThemeManager.shared.cardBackground)
        .cornerRadius(ThemeManager.shared.cardCornerRadius)
        .shadow(
            color: ThemeManager.shared.cardShadowColor.opacity(ThemeManager.shared.cardShadowOpacity * 2.5),
            radius: 12,
            x: 0,
            y: 6
        )
        .id(stableId)
        .onAppear {
            print("🔍 DEBUG: WorkOrderCardView appeared for WO: \(workOrder.workOrderNumber)")
            print("🔍 DEBUG: WorkOrder items count: \(workOrder.items.count)")
            for (index, item) in workOrder.items.enumerated() {
                print("🔍 DEBUG: Item \(index): \(item.type) - imageUrls: \(item.imageUrls.count), thumbUrls: \(item.thumbUrls.count)")
            }
        }
    }
}

struct WorkOrderCardContent: View {
    let workOrder: WorkOrder
    let customerTag: String?
    
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
            
            // Phone number (tappable)
            Button(action: { callCustomer() }) {
                Text(workOrder.customerPhone)
                    .font(ThemeManager.shared.labelFont)       // same size as customer name
                    .fontWeight(.bold)                         // bold
                    .underline()                               // underlined
                    .foregroundColor(ThemeManager.shared.linkColor)
                    .lineLimit(1)
            }
            .buttonStyle(PlainButtonStyle())

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

struct WorkOrderCardThumbnailGrid: View {
    let workOrder: WorkOrder

    // Layout dimensions
    private let singleHeight: CGFloat = 140      // unchanged (square path uses SquareThumb)
    private let doubleHeight: CGFloat = 112      // +12pt for better 2-up presence
    private let gridCell: CGFloat = 100          // larger cells for better visual balance
    private let spacing: CGFloat = 6             // tighter gutters per Notes style

    var body: some View {
        let totalItems = workOrder.items.count
        let displayCount = min(totalItems, 4)
        let imageInfos: [(url: URL?, item: WO_Item)] = Array(workOrder.items.prefix(displayCount)).map { item in
            (firstImageURL(for: item), item)
        }

        VStack(spacing: spacing) {
            if displayCount == 1 {
                // 1 item: ONE perfect square image
                if let info = imageInfos.first {
                    SquareThumb(
                        url: info.url,
                        itemStatus: StatusMapping.ItemStatus(for: info.item),
                        typeQtyLabel: "\(info.item.type.isEmpty ? "Item" : info.item.type) × 1"
                    )
                }
            } else if displayCount == 2 {
                // 2 items: TWO full-width rectangular images stacked vertically
                VStack(spacing: spacing) {
                    ForEach(Array(imageInfos.enumerated()), id: \.offset) { _, info in
                        FullWidthThumb(
                            url: info.url,
                            height: doubleHeight,
                            itemStatus: StatusMapping.ItemStatus(for: info.item),
                            typeQtyLabel: "\(info.item.type.isEmpty ? "Item" : info.item.type) × 1"
                        )
                    }
                }
            } else {
                // 3–4 items: 2×2 grid of larger tiles
                LazyVGrid(columns: [
                    GridItem(.fixed(gridCell), spacing: spacing),
                    GridItem(.fixed(gridCell), spacing: spacing)
                ], spacing: spacing) {
                    ForEach(Array(imageInfos.enumerated()), id: \.offset) { idx, info in
                        GridThumb(
                            url: info.url,
                            size: gridCell,
                            itemStatus: StatusMapping.ItemStatus(for: info.item),
                            showPlusBadge: (idx == 3 && totalItems > 4) ? (totalItems - 3) : nil,
                            typeQtyLabel: "\(info.item.type.isEmpty ? "Item" : info.item.type) × 1"
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)     // tighter top margin
        .onAppear {
            print("🔍 DEBUG: WorkOrderCardThumbnailGrid - totalItems: \(totalItems), displayCount: \(displayCount)")
            for (index, info) in imageInfos.enumerated() {
                print("🔍 DEBUG: ImageInfo \(index): URL = \(info.url?.absoluteString ?? "nil"), Item = \(info.item.type)")
            }
        }
    }

    // Always use the first image (index 0) from thumbUrls or imageUrls
    private func firstImageURL(for item: WO_Item) -> URL? {
        // Prefer thumbUrls[0], fall back to imageUrls[0]
        if !item.thumbUrls.isEmpty, let first = item.thumbUrls.first, let u = URL(string: first) { 
            return u 
        }
        if !item.imageUrls.isEmpty, let first = item.imageUrls.first, let u = URL(string: first) { 
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
                            .aspectRatio(contentMode: .fill)  // ⬅️ fill area, crop from center
                    case .failure:
                        Rectangle().fill(Color.red.opacity(0.25)).overlay(Text("❌"))
                    @unknown default:
                        Rectangle().fill(ThemeManager.shared.border.opacity(0.25))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width) // ⬅️ square
                .clipped()
                .cornerRadius(ThemeManager.shared.cardCornerRadius - 2)

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
    }
}

private struct FullWidthThumb: View {
    let url: URL?
    let height: CGFloat
    let itemStatus: StatusMapping.ItemStatus
    var typeQtyLabel: String = ""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(ThemeManager.shared.border.opacity(0.25))
                        .overlay(ProgressView().scaleEffect(0.9))
                        .onAppear {
                            print("🔍 DEBUG: FullWidthThumb AsyncImage EMPTY for URL: \(url?.absoluteString ?? "nil")")
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)  // ⬅️ fill area, crop from center
                        .onAppear {
                            print("✅ DEBUG: FullWidthThumb AsyncImage SUCCESS for URL: \(url?.absoluteString ?? "nil")")
                        }
                case .failure(let error):
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .overlay(Text("❌").font(.title))
                        .onAppear {
                            print("❌ DEBUG: FullWidthThumb AsyncImage FAILED for URL: \(url?.absoluteString ?? "nil") - Error: \(error)")
                        }
                @unknown default:
                    Rectangle()
                        .fill(ThemeManager.shared.border.opacity(0.25))
                        .overlay(Text("?").font(.title))
                        .onAppear {
                            print("⚠️ DEBUG: FullWidthThumb AsyncImage UNKNOWN for URL: \(url?.absoluteString ?? "nil")")
                        }
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(10)

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
            print("🔍 DEBUG: FullWidthThumb appeared for URL: \(url?.absoluteString ?? "nil")")
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
                        .aspectRatio(contentMode: .fill)  // ⬅️ fill area, crop from center
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
                
                Text(workOrder.customerPhone)
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
    
    WorkOrderCardView(workOrder: sampleWorkOrder)
        .padding()
}