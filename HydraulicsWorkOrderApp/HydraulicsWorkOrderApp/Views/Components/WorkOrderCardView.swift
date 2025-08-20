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

// ───── IMPORTS ─────
import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderCardView.swift
// Reusable grid card for each WorkOrder
// ─────────────────────────────────────────────────────────────
struct WorkOrderCardView: View {
    let workOrder: WorkOrder
    @Environment(\.openURL) private var openURL

    // Local state for resolved preview URL
    @State private var resolvedImageURL: URL? = nil

    // ───── Resolve preview from WorkOrder.imageURL only ─────
    private func resolveImageURL() {
        // Preferred: top-level preview URL
        let top = workOrder.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fallbacks: first item's thumb or full image
        let itemThumb = workOrder.items.first?.thumbUrls.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemFull  = workOrder.items.first?.imageUrls.first?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Choose first non-empty
        let chosen = [top, itemThumb, itemFull]
            .compactMap { $0 }
            .first { !$0.isEmpty }

        guard let s = chosen else {
            print("🛑 No preview candidates for WO \(workOrder.WO_Number) id=\(workOrder.id ?? "nil")")
            resolvedImageURL = nil
            return
        }

        if s.lowercased().hasPrefix("http") {
            print("🧩 Resolving full URL: \(s)")
            resolvedImageURL = URL(string: s)
        } else {
            StorageImageResolver.resolve(s) { url in
                self.resolvedImageURL = url
            }
        }
    }

    // ───── Helpers ─────
    private func digitsOnly(_ s: String) -> String { s.filter(\.isNumber) }

    @ViewBuilder private var placeholderImage: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            )
    }

    // ───── BODY ─────
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ───── Image Thumbnail (uses WorkOrder.imageURL) ─────
            ZStack {
                if let url = resolvedImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 140)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, minHeight: 140)
                                .clipped()
                        case .failure:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                } else {
                    placeholderImage
                }
            }
            .aspectRatio(4/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4))
            )

            // ───── Info Block ─────
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("WO \(workOrder.WO_Number)")
                        .font(.headline)
                    if workOrder.flagged {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    // Assuming you have these accessors on WorkOrder; if not, adjust as needed.
                    Text(workOrder.customerName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Button {
                        if let telURL = URL(string: "tel://\(digitsOnly(workOrder.customerPhone))") {
                            openURL(telURL)
                        }
                    } label: {
                        Text(workOrder.customerPhone)
                            .font(.caption)
                            .foregroundColor(Color(hex: "#FFC500"))
                            .underline()
                    }
                    .buttonStyle(.plain)
                }

                StatusBadge(status: workOrder.status)

                Text(workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        // Kick initial resolve, and re-resolve on changes
        .onAppear { resolveImageURL() }
        .onChange(of: workOrder.imageURL) { _, _ in resolveImageURL() }                         // top-level preview
        .onChange(of: workOrder.items.first?.thumbUrls.first) { _, _ in resolveImageURL() }     // first thumb
        .onChange(of: workOrder.items.first?.imageUrls.first) { _, _ in resolveImageURL() }     // first full
        .task(id: workOrder.lastModified) { resolveImageURL() }                                 // model bump
        .task(id: workOrder.WO_Number) { resolveImageURL() }                                    // identity bump
        .onReceive(NotificationCenter.default.publisher(for: .WOPendingPreviewUpdated)) { note in
            guard let woId = note.object as? String, woId == (workOrder.id ?? "") else { return }
            resolveImageURL()
        }
        .id(workOrder.lastModified) // force full re-render when model timestamp changes
        .padding()
    } // END .body
}
// END View

// ───── Preview Template ─────
#Preview(traits: .sizeThatFitsLayout) {
    WorkOrderCardView(workOrder: WorkOrder.sample)
}
// END
