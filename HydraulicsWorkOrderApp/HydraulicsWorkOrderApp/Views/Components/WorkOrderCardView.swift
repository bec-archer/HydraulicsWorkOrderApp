import SwiftUI
import Combine

// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.
// This file contains critical UI components that must maintain exact visual consistency.
// Only allowed modifications:
// - Fix compilation errors
// - Add missing imports
// - Correct type mismatches
// - Fix concurrency issues
// - Update deprecated API calls
// DO NOT modify:
// - View layouts, spacing, colors, fonts
// - UI component structure or hierarchy
// - Animation behaviors
// - User interaction patterns

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

// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.

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
            // Main content
            WorkOrderCardContent(workOrder: workOrder, customerTag: customerTag)
            
            // Image section
            if !imageResolver.resolvedImageURLs.isEmpty {
                WorkOrderCardThumbnails(
                    imageURLs: imageResolver.resolvedImageURLs,
                    workOrderNumber: workOrder.workOrderNumber
                )
            }
        }
        .background(Color.white) // White background for all work order cards
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .id(stableId) // Use stable ID instead of lastModified to prevent recreation
        .onChange(of: workOrderImageCount) {
            // Refresh images when work order image count changes
            imageResolver.resolveImageURLs()
        }
    }
    // END
}

// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.

struct WorkOrderCardContent: View {
    let workOrder: WorkOrder
    let customerTag: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Work order number and customer
                HStack {
                    Text(workOrder.workOrderNumber)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let emoji = workOrder.customerEmojiTag {
                        Text(emoji)
                            .font(.title2)
                    }
                    
                    Text(workOrder.customerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Item summary
                Text(itemSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Arrow
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var statusColor: Color {
        switch workOrder.status {
        case "Checked In": return UIConstants.StatusColors.checkedIn
        case "Disassembly": return UIConstants.StatusColors.disassembly
        case "In Progress": return UIConstants.StatusColors.inProgress
        case "Closed": return UIConstants.StatusColors.closed
        default: return UIConstants.StatusColors.fallback
        }
    }
    
    private var itemSummary: String {
        let itemCounts = getItemTypeCounts()
        if itemCounts.isEmpty {
            return "No items"
        }
        
        let summary = itemCounts.map { "\($0.count) \($0.type)" }.joined(separator: ", ")
        return summary
    }
    
    private func getItemTypeCounts() -> [ItemTypeCount] {
        var counts: [String: Int] = [:]
        
        for item in workOrder.items {
            counts[item.type, default: 0] += 1
        }
        
        let result = counts.map { ItemTypeCount(type: $0.key, count: $0.value) }
            .sorted { $0.type < $1.type }
        
        return result
    }
    
    private struct ItemTypeCount {
        let type: String
        let count: Int
    }
}

// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.

struct WorkOrderCardThumbnails: View {
    let imageURLs: [URL]
    let workOrderNumber: String
    
    private let thumbHeight: CGFloat = 60
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }
                .frame(width: thumbHeight, height: thumbHeight)
                .clipped()
                .cornerRadius(8)
            }
            
            // Fill remaining space if less than 4 images
            if imageURLs.count < 4 {
                ForEach(0..<(4 - imageURLs.count), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: thumbHeight, height: thumbHeight)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.

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

// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.

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
    
    // Helper function to get item type counts
    private func getItemTypeCounts() -> [ItemTypeCount] {
        var counts: [String: Int] = [:]
        
        for item in workOrder.items {
            counts[item.type, default: 0] += 1
        }
        
        let result = counts.map { ItemTypeCount(type: $0.key, count: $0.value) }
            .sorted { $0.type < $1.type }
        
        return result
    }
    
    private struct ItemTypeCount {
        let type: String
        let count: Int
    }
    
    private func digitsOnly(_ s: String) -> String { s.filter(\.isNumber) }
}

// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.


// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.

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