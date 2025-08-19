//  FullScreenImageViewer.swift
//  HydraulicsWorkOrderApp
//  Created by Bec Archer on 8/8/25.

import SwiftUI
import ImageIO

// ───── Full-Screen Image Viewer ─────

struct FullScreenImageViewer: View {
    let imageURL: URL
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.0
    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var loadedUIImage: UIImage? = nil // ✅ Manually loaded image

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea().background(.ultraThinMaterial)

                if let image = loadedUIImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(pinchScale * scale)
                        .offset(y: offset.height + dragOffset.height)
                        .gesture(
                            DragGesture()
                                .updating($dragOffset) { value, state, _ in
                                    state = value.translation
                                }
                                .onEnded { value in
                                    if abs(value.translation.height) > 100 {
                                        closeViewer()
                                    }
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .updating($pinchScale) { current, state, _ in
                                    state = current
                                }
                        )
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }

                // ✖️ Close Button (top-right)
                Button {
                    closeViewer()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                        .padding(16)
                }
                .accessibilityLabel("Close Image Viewer")
            }
            .transition(.scale)
        }
        .onAppear {
            print("🧩 FullScreenImageViewer launched with imageURL: \(imageURL.absoluteString)")

            var request = URLRequest(url: imageURL)
            request.setValue("image/jpeg", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Image load error: \(error.localizedDescription)")
                    return
                }
                print("🌐 Response: \(String(describing: response))")


                guard let data = data else {
                    print("❌ No data returned")
                    return
                }
                print("❌ No data received from: \(imageURL.absoluteString)")


                print("📦 Image data size: \(data.count) bytes")

                if let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.loadedUIImage = uiImage
                        print("✅ Image successfully loaded via UIImage(data:)")
                    }
                } else if let cgImageSource = CGImageSourceCreateWithData(data as CFData, nil),
                          let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) {
                    let fallbackImage = UIImage(cgImage: cgImage)
                    DispatchQueue.main.async {
                        self.loadedUIImage = fallbackImage
                        print("✅ Image successfully loaded via CGImage fallback")
                    }
                } else {
                    print("❌ Image decoding failed — neither UIImage nor CGImage succeeded")
                }
            }.resume()
        }
    }

    private func closeViewer() {
        withAnimation(.easeIn(duration: 0.2)) {
            scale = 0.95
            opacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
} // END

// ───── Preview Template ─────
#Preview {
    FullScreenImageViewer(
        imageURL: URL(string: "https://via.placeholder.com/600")!,
        isPresented: .constant(true)
    )
}
