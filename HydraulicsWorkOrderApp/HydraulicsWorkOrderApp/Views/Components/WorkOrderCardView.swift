//
//  WorkOrderCardView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderCardView.swift
// Reusable grid card for each WorkOrder
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct WorkOrderCardView: View {
    let workOrder: WorkOrder
    @Environment(\.openURL) private var openURL
    
    @State private var resolvedImageURL: URL? = nil

    // ───── Lifecycle: Resolve image URL on appear ─────
    private func resolveImageURL() {
        // Helper that accepts either a Storage path ("intake/...jpg") or a full URL ("https://...")
        func resolve(_ s: String) {
            if s.lowercased().hasPrefix("http") {
                // Already a full URL — no work needed
                self.resolvedImageURL = URL(string: s)
            } else {
                // Storage path — ask resolver to fetch a download URL
                StorageImageResolver.resolve(s) { url in
                    self.resolvedImageURL = url
                }
            }
        }

        if let s = workOrder.imageURL {
            resolve(s)
        } else if let s = workOrder.items.first?.imageUrls.first {
            resolve(s)
        } else {
            self.resolvedImageURL = nil
        }
    }

// End resolveImageURL


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


    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ───── Image Thumbnail (first photo) ─────
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
                    .stroke(Color(hex: "#E0E0E0"))
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
                    Text(workOrder.customerName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // ───── Tappable Phone (call, context menu for text) ─────
                    Button {
                        if let telURL = URL(string: "tel://\(digitsOnly(workOrder.customerPhone))") {
                            openURL(telURL)
                        }
                    } label: {
                        Text(workOrder.customerPhone)
                            .font(.caption)
                            .foregroundColor(Color(hex: "#FFC500")) // Yellow accent
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Text") {
                            if let smsURL = URL(string: "sms:\(digitsOnly(workOrder.customerPhone))") {
                                openURL(smsURL)
                            }
                        }
                    }

                }


                StatusBadge(status: workOrder.status)

                Text(workOrder.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            resolveImageURL()
        }
        // Re-resolve when WO_Item array changes (e.g., items added/removed)
        .onChange(of: workOrder.items.count) { _, _ in
            resolveImageURL()
        }
        // Re-resolve when the first WO_Item’s image count changes (new upload finished)
        .onChange(of: workOrder.items.first?.imageUrls.count ?? 0) { _, _ in
            resolveImageURL()
        }

        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

    }
}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    WorkOrderCardView(workOrder: WorkOrder.sample)
}
