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
    @State private var isPressed: Bool = false

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

    // Keep track of the last candidate to avoid redundant resolves/log spam
    @State private var lastResolvedCandidate: String? = nil

    // ───── Resolve preview (local coalesce: legacy-aware) ─────
    private func resolveImageURL() {
        guard let candidate = WorkOrderPreviewResolver.bestCandidate(from: workOrder) else {
            print("🛑 No preview candidates for WO \(workOrder.WO_Number) id=\(workOrder.id ?? "nil")")
            resolvedImageURL = nil
            lastResolvedCandidate = nil
            return
        }

        // Skip if we've already resolved this exact candidate
        if candidate == lastResolvedCandidate { return }
        lastResolvedCandidate = candidate

        if candidate.lowercased().hasPrefix("http") {
            print("🧩 Resolving full URL: \(candidate)")
            resolvedImageURL = URL(string: candidate)
        } else {
            // Allow resolver to map storage path → signed URL (async)
            StorageImageResolver.resolve(candidate) { url in
                self.resolvedImageURL = url
            }
        }
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
                                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180) // fixed thumbnail height
                                .clipped()
                        case .failure:
                            placeholderImage
                                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180)
                        @unknown default:
                            placeholderImage
                                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180)
                        }
                    }
                } else {
                    placeholderImage
                        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180)
                }
            }
            .frame(height: 180) // enforce uniform card image height
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
                        .lineLimit(1)
                        .truncationMode(.tail)
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
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Button {
                        if let telURL = URL(string: "tel://\(digitsOnly(workOrder.customerPhone))") {
                            openURL(telURL)
                        }
                    } label: {
                        Text(workOrder.customerPhone)
                            .font(.caption)
                            .foregroundColor(Color(hex: "#FFC500"))
                            .underline()
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                }

                StatusBadge(status: workOrder.status)

                Text(workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        // Kick initial resolve, and re-resolve on changes
        .onAppear { resolveImageURL() }
        .onChange(of: workOrder.imageURL) { _, _ in resolveImageURL() }                         // top-level preview
        .onChange(of: workOrder.items.first?.thumbUrls) { _, _ in resolveImageURL() }           // any thumb change
        .onChange(of: workOrder.items.first?.imageUrls) { _, _ in resolveImageURL() }           // any full change
        .onChange(of: workOrder.imageURLs) { _, _ in resolveImageURL() }                        // legacy plural
        .task(id: workOrder.lastModified) { resolveImageURL() }                                 // model bump
        .task(id: workOrder.WO_Number) { resolveImageURL() }                                    // identity bump
        .onReceive(NotificationCenter.default.publisher(for: .WOPendingPreviewUpdated)) { note in
            guard let woId = note.object as? String, woId == (workOrder.id ?? "") else { return }
            resolveImageURL()
        }
        .id(workOrder.lastModified) // force full re-render when model timestamp changes
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // ───── Pressed-State Border (outer card) ─────
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isPressed ? Color(.systemGray2) : Color.clear, lineWidth: isPressed ? 2 : 0)
        )
        // ───── Subtle Depth ─────
        .shadow(color: Color.black.opacity(isPressed ? 0.18 : 0.12), radius: isPressed ? 8 : 6, x: 0, y: isPressed ? 4 : 3)
        // ───── Press Animation ─────
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.26, dampingFraction: 0.82, blendDuration: 0.2), value: isPressed)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        // ───── Press Feedback that doesn't steal taps ─────
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) // ensure whole card is tappable
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onDisappear { isPressed = false }
    } // END .body
}
// END View

// ───── Preview Template ─────
#Preview(traits: .sizeThatFitsLayout) {
    WorkOrderCardView(workOrder: WorkOrder.sample)
}
// END
