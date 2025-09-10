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
    
    private let workOrderNumber: String
    private var cancellables = Set<AnyCancellable>()
    
    init(workOrderNumber: String) {
        self.workOrderNumber = workOrderNumber
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
            print("⚠️ IMAGE: Already resolving for WO \(workOrderNumber)")
            return
        }
        
        isResolving = true
        print("🔄 IMAGE: Resolving images for WO \(workOrderNumber)")
        
        // Get the work order from cache on main actor
        Task { @MainActor in
            guard let workOrder = WorkOrdersDatabase.shared.workOrders.first(where: { $0.workOrderNumber == workOrderNumber }) else {
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
            print("📋 Final URLs for WO \(workOrderNumber) (immediate):")
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
    
    @StateObject private var imageResolver: ImageResolverViewModel
    
    init(workOrder: WorkOrder, customerTag: String? = nil) {
        self.workOrder = workOrder
        self.customerTag = customerTag
        self._imageResolver = StateObject(wrappedValue: ImageResolverViewModel(workOrderNumber: workOrder.workOrderNumber))
    }
    
    // Add a stable identifier to prevent unnecessary recreation
    private var stableId: String {
        workOrder.workOrderNumber
    }
    
    // Track work order changes to refresh images
    private var workOrderImageCount: Int {
        workOrder.items.reduce(0) { $0 + $1.imageUrls.count + $1.thumbUrls.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail Grid (2x2, up to 4 images)
            WorkOrderCardThumbnailGrid(
                imageURLs: imageResolver.resolvedImageURLs,
                workOrder: workOrder
            )
            
            // Main content
            WorkOrderCardContent(workOrder: workOrder, customerTag: customerTag)
        }
        .background(ThemeManager.shared.cardBackground)
        .cornerRadius(ThemeManager.shared.cardCornerRadius)
        .shadow(
            color: ThemeManager.shared.cardShadowColor.opacity(ThemeManager.shared.cardShadowOpacity),
            radius: 4,
            x: 0,
            y: 2
        )
        .id(stableId)
        .onChange(of: workOrderImageCount) {
            imageResolver.resolveImageURLs()
        }
    }
}

struct WorkOrderCardContent: View {
    let workOrder: WorkOrder
    let customerTag: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // WO_Number with inline dots and timestamp
            HStack {
                Text(workOrder.workOrderNumber)
                    .font(ThemeManager.shared.labelFont)
                    .foregroundColor(ThemeManager.shared.textPrimary)
                
                // Inline dots (up to 4, one per WO_Item)
                HStack(spacing: 4) {
                    ForEach(Array(StatusMapping.itemStatusesWithColor(for: workOrder).enumerated()), id: \.offset) { _, itemStatus in
                        IndicatorDot(color: itemStatus.color, size: 6)
                    }
                }
                
                Spacer()
                
                // Timestamp
                Text(timeAgoString)
                    .font(.caption)
                    .foregroundColor(ThemeManager.shared.textSecondary)
            }
            
            // Customer name with emoji and flag
            HStack {
                // Customer emoji (if present)
                if let emoji = workOrder.customerEmojiTag {
                    Text(emoji)
                        .font(.title3)
                }
                
                Text(workOrder.customerName)
                    .font(ThemeManager.shared.bodyFont)
                    .foregroundColor(ThemeManager.shared.textPrimary)
                
                Spacer()
                
                // Flag icon (if flagged)
                if workOrder.flagged {
                    Image(systemName: "flag.fill")
                        .foregroundColor(ThemeManager.shared.linkColor)
                        .font(.caption)
                }
            }
            
            // Phone number (tappable)
            Button(action: {
                callCustomer()
            }) {
                Text(workOrder.customerPhone)
                    .font(.caption)
                    .foregroundColor(ThemeManager.shared.linkColor)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: workOrder.timestamp, relativeTo: Date())
    }
    
    private func callCustomer() {
        let phoneNumber = workOrder.customerPhone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if let url = URL(string: "tel:\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
}

struct WorkOrderCardThumbnailGrid: View {
    let imageURLs: [URL]
    let workOrder: WorkOrder
    
    private let thumbSize: CGFloat = 60
    private let spacing: CGFloat = 6
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.fixed(thumbSize), spacing: spacing),
            GridItem(.fixed(thumbSize), spacing: spacing)
        ], spacing: spacing) {
            ForEach(Array(imageURLs.prefix(4).enumerated()), id: \.offset) { index, url in
                ThumbnailWithOverlayDot(
                    url: url,
                    size: thumbSize,
                    itemStatus: getItemStatusForImage(index: index)
                )
            }
            
            // Fill remaining slots if less than 4 images
            if imageURLs.count < 4 {
                ForEach(imageURLs.count..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(ThemeManager.shared.border.opacity(0.3))
                        .frame(width: thumbSize, height: thumbSize)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    private func getItemStatusForImage(index: Int) -> StatusMapping.ItemStatus {
        guard index < workOrder.items.count else {
            // Create a fallback WO_Item with "Checked In" status
            let fallbackItem = WO_Item(
                id: UUID(),
                type: "Unknown",
                statusHistory: [
                    WO_Status(status: "Checked In", user: "System", timestamp: Date(), notes: nil)
                ]
            )
            return StatusMapping.ItemStatus(for: fallbackItem)
        }
        return StatusMapping.ItemStatus(for: workOrder.items[index])
    }
}

struct ThumbnailWithOverlayDot: View {
    let url: URL
    let size: CGFloat
    let itemStatus: StatusMapping.ItemStatus
    
    var body: some View {
        ZStack {
            // Thumbnail image
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(ThemeManager.shared.border.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
            .frame(width: size, height: size)
            .clipped()
            .cornerRadius(8)
            
            // Overlay dot (top-right corner)
            VStack {
                HStack {
                    Spacer()
                    OverlayDot(color: itemStatus.color, size: 10)
                        .offset(x: 4, y: -4)
                }
                Spacer()
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