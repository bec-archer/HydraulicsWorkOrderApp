//
//  NotesTimelineView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/18/25.
//
import SwiftUI

// ───── NotesTimelineView ─────

struct NotesTimelineView: View {
    let notes: [WO_Note]

    @State private var showFullScreen = false
    @State private var selectedImageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Notes + Status Updates")
                .font(.title3.bold())

            let sortedNotes = notes.sorted { $0.timestamp > $1.timestamp }

            ForEach(sortedNotes, id: \.id) { note in
                VStack(alignment: .leading, spacing: 6) {

                    // 🗒 Note Text
                    Text("• \(note.text)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // 👤 User + Timestamp
                    Text("— \(note.user), \(note.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.gray)

                    // 🖼 Image Thumbnails
                    if !note.imageUrls.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(note.imageUrls, id: \.self) { url in
                                    AsyncImage(url: URL(string: url)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipped()
                                                .cornerRadius(8)
                                                .onTapGesture {
                                                    print("🟡 Thumbnail tapped: \(url)")

                                                    if let validURL = URL(string: url),
                                                       UIApplication.shared.canOpenURL(validURL) {
                                                        print("✅ Valid URL for viewer: \(validURL)")
                                                        selectedImageURL = validURL
                                                        showFullScreen = true
                                                    } else {
                                                        print("❌ Invalid or unopenable URL: \(url)")
                                                    }
                                                }


                                        case .failure(_):
                                            Image(systemName: "exclamationmark.triangle")
                                                .frame(width: 100, height: 100)
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 100, height: 100)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .onChange(of: selectedImageURL) { _, newValue in
            if let url = newValue {
                print("📤 selectedImageURL was set to: \(url.absoluteString)")
            }
        }

        .sheet(isPresented: $showFullScreen) {
            if let url = selectedImageURL {
                FullScreenImageViewer(imageURL: url, isPresented: $showFullScreen)
            }
        }
    }
}

// END

// ───── Preview Template ─────

#Preview {
    NotesTimelineView(notes: [
        WO_Note(
            workOrderId: "PREVIEW-WO-001",
            user: "Maria",
            text: "This one leaks worse under pressure.",
            timestamp: Date().addingTimeInterval(-3600),
            imageUrls: [
                "https://via.placeholder.com/150",
                "https://via.placeholder.com/150/000000/FFFFFF"
            ]
        ),
        WO_Note(
            workOrderId: "PREVIEW-WO-001",
            user: "Joe",
            text: "Replaced seals. Retest tomorrow.",
            timestamp: Date()
        )
    ])
    .padding()
}
