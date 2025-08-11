//  WOItemAccordionRow.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/11/25.

import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 WOItemAccordionRow.swift
// Collapsible inline form for a single WO_Item.
// ─────────────────────────────────────────────────────────────

struct WOItemAccordionRow: View {
    let index: Int
    @Binding var items: [WO_Item]
    @Binding var expandedIndex: Int?
    let onDelete: (Int) -> Void

    @State private var isUploadingImages = false

    private var isExpanded: Binding<Bool> {
        Binding<Bool>(
            get: { expandedIndex == index },
            set: { newValue in
                withAnimation {
                    expandedIndex = newValue ? index : nil
                }
            }
        )
    }

    // ───── BODY ─────
    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {

            // ───── Expanded Content (Form + Photos) ─────
            AddWOItemFormView(item: $items[index])
                .padding(.top, 6)

            PhotoCaptureView(images: $items[index].localImages)
                .padding(.top, 6)
                .onChange(of: items[index].localImages.count) { _, _ in
                    Task { await uploadNewLocalImages() }
                }

            Text("📸 Local image count: \(items[index].localImages.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isUploadingImages {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Uploading photos…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // ───── Danger Zone: Delete ─────
            HStack {
                Spacer()
                Button {
                    onDelete(index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.red, in: Circle())
                }
                .accessibilityLabel("Delete Item")
                .buttonStyle(.plain)
            }
            // END Danger Zone

        } label: {
            // ───── WO_Item Header Label ─────
            HStack(spacing: 8) {
                Text(headerTitle(for: items[index]))
                    .font(hasUserEnteredData(items[index]) ? .headline : .body)
                    .foregroundStyle(hasUserEnteredData(items[index]) ? .primary : .secondary)

                Spacer()

                if let summary = summaryText(for: items[index]) {
                    Text(summary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let thumb = items[index].localImages.first {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(hex: "#E0E0E0"))
                        )
                } else {
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // END DisclosureGroup
    }
    // END .body


    // ───── Helper: Did user enter anything yet? ─────
    private func hasUserEnteredData(_ item: WO_Item) -> Bool {
        if let tag = item.tagId, !tag.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if !item.imageUrls.isEmpty { return true }
        if !item.type.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if item.dropdowns.values.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { return true }
        if !item.reasonsForService.isEmpty { return true }
        if let notes = item.reasonNotes, !notes.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return false
    }

    // ───── Helper: Header Title for WO_Item Row ─────
    private func headerTitle(for item: WO_Item) -> String {
        hasUserEnteredData(item) ? "Item" : "New Item"
    }

    // ───── Helper: Optional summary text (only if there’s data) ─────
    private func summaryText(for item: WO_Item) -> String? {
        guard hasUserEnteredData(item) else { return nil }
        var bits: [String] = []
        if let t = (item.type.isEmpty ? item.dropdowns["type"] : item.type), !t.isEmpty {
            bits.append(t)
        }
        if let size = item.dropdowns["size"], !size.isEmpty { bits.append(size) }
        if let color = item.dropdowns["color"], !color.isEmpty { bits.append(color) }
        return bits.isEmpty ? nil : bits.joined(separator: " • ")
    }

    // ───── Image Upload Handler ─────
    private func uploadNewLocalImages() async {
        let alreadyUploaded = items[index].imageUrls.count
        let pending = items[index].localImages.indices.filter { $0 >= alreadyUploaded }
        guard !pending.isEmpty else { return }

        await MainActor.run { isUploadingImages = true }

        for idx in pending {
            let image = items[index].localImages[idx]
            if let urlString = try? await StorageManager.shared.uploadWOItemImage(image, woItemId: items[index].id) {
                await MainActor.run {
                    items[index].imageUrls.append(urlString)
                }
            }
        }

        await MainActor.run { isUploadingImages = false }
    }
    // END Handler
}

// ───── Preview Template ─────
#Preview {
    WOItemAccordionRow(index: 0, items: .constant([WO_Item.sample]), expandedIndex: .constant(0), onDelete: { _ in })
}
// END FILE
