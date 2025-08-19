//  FullScreenImageViewer.swift
//  HydraulicsWorkOrderApp
//  Created by Bec Archer on 8/8/25.
//
import SwiftUI

// ───── Full-Screen Image Viewer ─────

struct FullScreenImageViewer: View {
    let imageURL: URL
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.0
    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea().background(.ultraThinMaterial)

                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                    case .success(let image):
                        image
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

                    case .failure(let error):
                        VStack(spacing: 12) {
                            Image(systemName: "xmark.octagon")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            Text("Failed to load image")
                                .foregroundColor(.white)
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                    @unknown default:
                        EmptyView()
                    }
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
}

// END

// ───── Preview Template ─────
#Preview {
    FullScreenImageViewer(
        imageURL: URL(string: "https://via.placeholder.com/600")!,
        isPresented: .constant(true)
    )
}
