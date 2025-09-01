//  FullScreenImageViewer.swift
//  HydraulicsWorkOrderApp
//  Created by Bec Archer on 8/8/25.

import SwiftUI
import ImageIO

// ───── Full-Screen Image Viewer (Overlay Style) ─────

struct FullScreenImageViewer: View {
    let imageURL: URL
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.0
    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var loadedUIImage: UIImage? = nil // ✅ Manually loaded image
    @State private var loadFailed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Dimming overlay background (ensures viewer sits above other overlays/sheets)
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle()) // make entire dim area tappable
                .onTapGesture { closeViewer() }
                .zIndex(0)

            if let image = loadedUIImage {
                ZStack {
                    // Subtle background that covers the image area
                    Color.black.opacity(0.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(pinchScale * scale)
                        .offset(y: offset.height + dragOffset.height)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(1) // keep the image above the dim background and other overlays
                } // end inner image ZStack
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
                .onTapGesture {
                    // Prevent tap from closing when tapping on the image
                }
                .zIndex(1)
            } else if loadFailed {
                VStack {
                    Text("❌ Failed to load image")
                        .foregroundColor(.white)
                        .font(.headline)
                    Text(imageURL.absoluteString)
                        .foregroundColor(.gray)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding()
                }
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
            .zIndex(2)
        }
        .zIndex(9999)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.8)).animation(.easeOut(duration: 0.3)),
            removal: .opacity.combined(with: .scale(scale: 1.1)).animation(.easeIn(duration: 0.2))
        ))
        .onAppear {
            print("🧩 FullScreenImageViewer launched with imageURL: \(imageURL.absoluteString)")

#if DEBUG
            // Show a quick placeholder, but still fetch the real image
            if loadedUIImage == nil {
                self.loadedUIImage = UIImage(systemName: "photo")
            }
#endif

            var request = URLRequest(url: imageURL)
            request.setValue("image/jpeg", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Image load error: \(error.localizedDescription)")
                    DispatchQueue.main.async { self.loadFailed = true }
                    return
                }

                print("🌐 Response: \(String(describing: response))")

                guard let data = data else {
                    print("❌ No data received from: \(imageURL.absoluteString)")
                    DispatchQueue.main.async {
                        self.loadFailed = true
                    }
                    return
                }

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
