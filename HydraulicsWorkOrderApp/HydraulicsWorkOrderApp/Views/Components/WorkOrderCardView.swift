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


// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderCardView.swift
// Reusable grid card for each WorkOrder
// ─────────────────────────────────────────────────────────────
struct WorkOrderCardView: View {
    let workOrder: WorkOrder
    @Environment(\.openURL) private var openURL

    @State private var resolvedImageURLs: [URL?] = []
    @State private var isPressed: Bool = false
    @State private var lastResolvedCandidates: [String?] = []

    private let thumbHeight: CGFloat = 200 // Made square by matching width

    // ───── Change Tracking Keys (to reduce type‑checker load) ─────
    private var imageURLKey: String { workOrder.imageURL ?? "" }
    private var itemsKey: String { workOrder.items.map { "\($0.id)-\($0.imageUrls.first ?? "")" }.joined(separator: ",") }
    private var imageURLsKey: String { (workOrder.imageURLs ?? []).joined(separator: ",") }
    // END

    var body: some View {
        coreContent
            .background(eventBinder) // lifecycle & notifications separated
            .modifier(CardChrome(isPressed: $isPressed)) // visual chrome
            .modifier(CardPressGesture(isPressed: $isPressed)) // press gesture
    }

    // ───── Core Content (extracted) ─────
    private var coreContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardThumbnail
            InfoBlockView(workOrder: workOrder, openURL: openURL)
        }
        .id(workOrder.lastModified)
    }
    // END

    // ───── Event Binder (onAppear/onChange/tasks/notifications) ─────
    private var eventBinder: some View {
        Color.clear
            .onAppear { resolveImageURLs() }
            .onChange(of: imageURLKey) { _, _ in resolveImageURLs() }
            .onChange(of: itemsKey) { _, _ in resolveImageURLs() }
            .onChange(of: imageURLsKey) { _, _ in resolveImageURLs() }
            .task(id: workOrder.lastModified) { resolveImageURLs() }
            .task(id: workOrder.WO_Number) { resolveImageURLs() }
            .onReceive(NotificationCenter.default.publisher(for: .WOPendingPreviewUpdated)) { note in
                guard let woId = note.object as? String, woId == (workOrder.id ?? "") else { return }
                resolveImageURLs()
            }
            .onReceive(NotificationCenter.default.publisher(for: .WOPreviewAvailable)) { note in
                guard
                    let info = note.userInfo as? [String: Any],
                    let number = info["WO_Number"] as? String,
                    number == workOrder.WO_Number,
                    let s = info["url"] as? String
                else { return }

                if let url = URL(string: s) {
                    // For legacy support, update first image
                    if !self.resolvedImageURLs.isEmpty {
                        self.resolvedImageURLs[0] = url
                    }
                } else {
                    StorageImageResolver.resolve(s) { url in
                        if !self.resolvedImageURLs.isEmpty {
                            self.resolvedImageURLs[0] = url
                        }
                    }
                }
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

    private func resolveImageURLs() {
        #if DEBUG
        print("🔍 WorkOrderCardView.resolveImageURLs for WO \(workOrder.WO_Number):")
        print("  - items.count: \(workOrder.items.count)")
        for (index, item) in workOrder.items.enumerated() {
            print("  - Item \(index): type='\(item.type)', images=\(item.imageUrls.count)")
        }
        #endif
        
        // Get first image from each item
        var newURLs: [URL?] = []
        var newCandidates: [String?] = []
        
        for item in workOrder.items {
            let candidate = item.imageUrls.first ?? item.thumbUrls.first
            newCandidates.append(candidate)
            
            if let candidate = candidate {
                if candidate.lowercased().hasPrefix("http") {
                    newURLs.append(URL(string: candidate))
                } else {
                    newURLs.append(nil) // Will be resolved by StorageImageResolver
                    StorageImageResolver.resolve(candidate) { url in
                        if let index = newCandidates.firstIndex(of: candidate) {
                            DispatchQueue.main.async {
                                if index < self.resolvedImageURLs.count {
                                    self.resolvedImageURLs[index] = url
                                }
                            }
                        }
                    }
                }
            } else {
                newURLs.append(nil)
            }
        }
        
        // Check if anything changed
        let currentCandidates = lastResolvedCandidates
        if currentCandidates == newCandidates { return }
        
        lastResolvedCandidates = newCandidates
        resolvedImageURLs = newURLs
    }

     // ───── Card Thumbnail (extracted to aid type‑checker) ─────
     private var cardThumbnail: AnyView {
         AnyView(
             GridThumbnailView(
                 resolvedImageURLs: resolvedImageURLs,
                 thumbHeight: thumbHeight,
                 placeholderImage: AnyView(placeholderImage)
             )
             .frame(height: thumbHeight)
             .clipShape(RoundedRectangle(cornerRadius: 12))
             .overlay(
                 RoundedRectangle(cornerRadius: 12)
                     .stroke(Color(.systemGray4))
             )
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
    let resolvedImageURLs: [URL?]
    let thumbHeight: CGFloat
    let placeholderImage: AnyView

    var body: some View {
        if resolvedImageURLs.isEmpty {
            placeholderImage
                .frame(maxWidth: .infinity, minHeight: thumbHeight, maxHeight: thumbHeight)
        } else if resolvedImageURLs.count == 1 {
            // Single image - full width
            if let url = resolvedImageURLs[0] {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: thumbHeight, maxHeight: thumbHeight)
                        .clipped()
                } placeholder: {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: thumbHeight, maxHeight: thumbHeight)
                }
            } else {
                placeholderImage
                    .frame(maxWidth: .infinity, minHeight: thumbHeight, maxHeight: thumbHeight)
            }
        } else {
            // Multiple images - grid layout
            LazyVGrid(columns: gridColumns, spacing: 2) {
                ForEach(Array(resolvedImageURLs.enumerated()), id: \.offset) { index, url in
                    if let url = url {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, minHeight: gridItemHeight, maxHeight: gridItemHeight)
                                .clipped()
                        } placeholder: {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: gridItemHeight, maxHeight: gridItemHeight)
                        }
                    } else {
                        placeholderImage
                            .frame(maxWidth: .infinity, minHeight: gridItemHeight, maxHeight: gridItemHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: thumbHeight, maxHeight: thumbHeight)
        }
    }
    
    private var gridColumns: [GridItem] {
        if resolvedImageURLs.count == 2 {
            // 2 items: side by side
            return [
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2)
            ]
        } else {
            // 3+ items: 2x2 grid
            return [
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2)
            ]
        }
    }
    
    private var gridItemHeight: CGFloat {
        if resolvedImageURLs.count == 2 {
            return thumbHeight // Full height for 2 items
        } else {
            return (thumbHeight - 2) / 2 // Half height for 2x2 grid
        }
    }
}

// ───── InfoBlockView Subview ─────
struct InfoBlockView: View {
    let workOrder: WorkOrder
    let openURL: OpenURLAction

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("WO \(workOrder.WO_Number)")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if workOrder.flagged {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.red)
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

                Button {
                    if let telURL = URL(string: "tel://\(digitsOnly(workOrder.customerPhone))") {
                        openURL(telURL)
                    }
                } label: {
                    Text(workOrder.customerPhone)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#FFC500"))
                        .underline()
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.plain)
            }

            StatusBadge(status: workOrder.status)

            HStack {
                Text(workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                // Display item types inline with timestamp
                VStack(alignment: .trailing, spacing: 1) {
                    ForEach(getItemTypeCounts(), id: \.type) { itemInfo in
                        Text("\(itemInfo.type) x \(itemInfo.count)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .frame(minHeight: 20) // Ensure consistent height even when empty
            }
            
            Spacer()
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
}

// ───── Preview Template ─────
#Preview(traits: .sizeThatFitsLayout) {
    WorkOrderCardView(workOrder: WorkOrder.sample)
}
