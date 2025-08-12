//  WOItemAccordionRow.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/11/25.

// ─────────────────────────────────────────────────────────────
// 📄 WOItemAccordionRow.swift
// Collapsible inline form for a single WO_Item.
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct WOItemAccordionRow: View {
    let index: Int
    let woId: String                     // ⬅️ parent WorkOrder ID
    @Binding var items: [WO_Item]
    @Binding var expandedIndex: Int?
    let onDelete: (Int) -> Void


    @State private var isUploadingImages = false

    // ───── Index Safety Helpers ─────
    private var indexIsValid: Bool { items.indices.contains(index) }

    private var itemBinding: Binding<WO_Item> {
        Binding(
            get: { indexIsValid ? items[index] : WO_Item.blank() },
            set: { newValue in if indexIsValid { items[index] = newValue } }
        )
    }

    private var imagesBinding: Binding<[UIImage]> {
        Binding(
            get: { indexIsValid ? items[index].localImages : [] },
            set: { newValue in if indexIsValid { items[index].localImages = newValue } }
        )
    }
    // ───── End Index Safety Helpers ─────

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedIndex == index },
            set: { newValue in
                withAnimation { expandedIndex = newValue ? index : nil }
            }
        )
    }

    // ───── BODY ─────
    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            if !indexIsValid {
                EmptyView()
            } else {
                // ───── Expanded Content (Photos + Form) ─────

                // Required field header
                HStack(spacing: 4) {
                    Text("Photos").font(.headline)
                    Text("*").foregroundColor(.red).font(.headline)
                }
                .padding(.top, 6)

                // Image capture + QR scan row
                HStack {
                    PhotoCaptureView(images: imagesBinding)
                        .onChange(of: imagesBinding.wrappedValue.count) { _, _ in
                            Task { await uploadNewLocalImages() }
                        }

                    Spacer()

                    Button {
                        // TODO: Implement QR code scanner logic
                        if indexIsValid {
                            print("Scan QR Code tapped for item \(items[index].id)")
                        }
                    } label: {
                        Text("Scan QR Code")
                            .font(.callout).fontWeight(.semibold)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color(hex: "#007AFF"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)

                // Inline form
                AddWOItemFormView(item: itemBinding)
                    .padding(.top, 6)
                // END expanded content
            }

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
                Button { onDelete(index) } label: {
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
            let headerItem = indexIsValid ? items[index] : WO_Item.blank()

            HStack(spacing: 8) {
                Text(headerTitle(for: headerItem))
                    .font(hasUserEnteredData(headerItem) ? .headline : .body)
                    .foregroundStyle(hasUserEnteredData(headerItem) ? .primary : .secondary)

                Spacer()

                if let summary = summaryText(for: headerItem) {
                    Text(summary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let thumb = headerItem.localImages.first {
                    VStack(spacing: 2) {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(hex: "#E0E0E0"))
                            )
                        Text("\(headerItem.localImages.count) pic\(headerItem.localImages.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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

    // ───── Helper: Optional summary text ─────
    private func summaryText(for item: WO_Item) -> String? {
        guard hasUserEnteredData(item) else { return nil }
        var bits: [String] = []
        if let t = (item.type.isEmpty ? item.dropdowns["type"] : item.type), !t.isEmpty { bits.append(t) }
        if let size = item.dropdowns["size"], !size.isEmpty { bits.append(size) }
        if let color = item.dropdowns["color"], !color.isEmpty { bits.append(color) }
        return bits.isEmpty ? nil : bits.joined(separator: " • ")
    }

    // ───── Image Upload Handler ─────
    private func uploadNewLocalImages() async {
        // If our row was deleted or reordered mid-flight, bail.
        guard indexIsValid else { return }

        let alreadyUploaded = items[index].imageUrls.count
        let localCount = items[index].localImages.count
        guard localCount > alreadyUploaded else { return }

        let pending = items[index].localImages.indices.filter { $0 >= alreadyUploaded }
        guard !pending.isEmpty else { return }

        await MainActor.run { isUploadingImages = true }

        for idx in pending {
            // Re-check index every iteration in case user deletes the row
            guard indexIsValid, idx < items[index].localImages.count else { continue }
            let image = items[index].localImages[idx]

            if let urlString = try? await StorageManager.shared.uploadWOItemImage(image, woId: woId, woItemId: items[index].id) {

                await MainActor.run {
                    if indexIsValid { items[index].imageUrls.append(urlString) }
                }
            }
        }

        await MainActor.run { isUploadingImages = false }
    }
    // END Handler
}

// ───── Preview Template ─────
#Preview {
    WOItemAccordionRow(
        index: 0,
        woId: "SAMPLE_WO_ID",
        items: .constant([WO_Item.sample]),
        expandedIndex: .constant(0),
        onDelete: { _ in }
    )
}
// END FILE
