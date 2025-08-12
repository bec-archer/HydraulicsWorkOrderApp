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

    // ───── Derived: Card thumbnail URL ─────
    private var cardImageURL: URL? {
        // Prefer WorkOrder.imageURL, else first WO_Item image
        if let s = workOrder.imageURL, let u = URL(string: s) { return u }
        if let s = workOrder.items.first?.imageUrls.first, let u = URL(string: s) { return u }
        return nil
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


    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ───── Image Thumbnail (first photo) ─────
            ZStack {
                if let url = cardImageURL {
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
