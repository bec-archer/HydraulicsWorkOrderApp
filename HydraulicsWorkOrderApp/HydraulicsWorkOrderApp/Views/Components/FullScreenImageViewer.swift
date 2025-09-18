//  FullScreenImageViewer.swift
//  HydraulicsWorkOrderApp
//  Created by Bec Archer on 8/8/25.

import SwiftUI
import ImageIO

// ───── Full-Screen Image Viewer (Overlay Style) ─────

struct FullScreenImageViewer: View {
    let imageURL: URL
    @Binding var isPresented: Bool
    
    // Optional parameters for edit/revert functionality
    var workOrderId: String? = nil
    var itemId: UUID? = nil
    
    // Callback to notify parent when image is edited
    var onImageEdited: (() -> Void)? = nil
    
    // Initialize currentImageURL with the original imageURL
    init(imageURL: URL, isPresented: Binding<Bool>, workOrderId: String? = nil, itemId: UUID? = nil, onImageEdited: (() -> Void)? = nil) {
        self.imageURL = imageURL
        self._isPresented = isPresented
        self.workOrderId = workOrderId
        self.itemId = itemId
        self.onImageEdited = onImageEdited
        self._currentImageURL = State(initialValue: imageURL)
    }

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.0
    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var loadedUIImage: UIImage? = nil // ✅ Manually loaded image
    @State private var loadFailed = false
    
    // ───── SECTION: State ─────
    @State private var showMarkup = false
    @State private var baseUIImage: UIImage? = nil
    @State private var isBusy = false

    @State private var lastOldURLForRevert: String? = nil
    @State private var lastNewURLForRevert: String? = nil
    @State private var lastEditedStoragePath: String? = nil
    
    // Track the current image URL (may change after editing)
    @State private var currentImageURL: URL

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
            VStack {
                HStack {
                    Spacer()
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
                
                Spacer()
                
                // Edit and Revert buttons (bottom overlay)
                HStack(spacing: 20) {
                    Button {
                        print("🧩 Edit button tapped - workOrderId: \(workOrderId ?? "nil"), itemId: \(itemId?.uuidString ?? "nil")")
                        showMarkup = true
                    } label: {
                        Image(systemName: "pencil.tip.crop.circle")
                            .font(.title)
                            .foregroundColor(baseUIImage == nil ? .white.opacity(0.35) : .white)
                            .padding()
                    }
                    .disabled(baseUIImage == nil)

                    if lastOldURLForRevert != nil && lastNewURLForRevert != nil {
                        Button {
                            print("🧩 Revert button tapped")
                            Task { await revertToOriginalTapped() }
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                        }
                        .disabled(isBusy)
                    }
                }
                .padding(.bottom, 50)
            }
            .zIndex(2)
        }
        .zIndex(9999)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.8)).animation(.easeOut(duration: 0.3)),
            removal: .opacity.combined(with: .scale(scale: 1.1)).animation(.easeIn(duration: 0.2))
        ))
        .sheet(isPresented: $showMarkup) {
            if let ui = baseUIImage {
                ImageMarkupView(
                    baseImage: ui,
                    onCancel: { 
                        print("🧩 ImageMarkupView onCancel called")
                        showMarkup = false 
                    },
                    onSave: { merged, overlayPNG, drawingData in
                        print("🧩 ImageMarkupView onSave called")
                        showMarkup = false
                        Task { await replaceWithEdited(merged: merged, overlayPNG: overlayPNG, drawingData: drawingData) }
                    }
                )
                .onAppear {
                    print("🧩 ImageMarkupView sheet presenting with baseImage")
                }
            } else {
                Text("No base image available")
                    .foregroundColor(.white)
                    .background(Color.black)
                    .onAppear {
                        print("🧩 ImageMarkupView sheet triggered but baseUIImage is nil")
                    }
            }
        }
        .onAppear {
            print("🧩 FullScreenImageViewer launched with imageURL: \(imageURL.absoluteString)")
            print("🧩 FullScreenImageViewer isPresented: \(isPresented)")
            print("🧩 FullScreenImageViewer workOrderId: \(workOrderId ?? "nil")")
            print("🧩 FullScreenImageViewer itemId: \(itemId?.uuidString ?? "nil")")
            
            // Only load from URL if we don't already have an image loaded
            if loadedUIImage == nil {
                captureUIImageIfNeeded(from: currentImageURL)

#if DEBUG
                // Show a quick placeholder, but still fetch the real image
                self.loadedUIImage = UIImage(systemName: "photo")
#endif

                var request = URLRequest(url: currentImageURL)
                request.setValue("image/jpeg", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Image load error: \(error.localizedDescription)")
                    DispatchQueue.main.async { self.loadFailed = true }
                    return
                }

                print("🌐 Response: \(String(describing: response))")
                
                // Debug: Show HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 DEBUG: HTTP Status Code: \(httpResponse.statusCode)")
                    print("🔍 DEBUG: HTTP Headers: \(httpResponse.allHeaderFields)")
                }

                guard let data = data else {
                    print("❌ No data received from: \(imageURL.absoluteString)")
                    DispatchQueue.main.async {
                        self.loadFailed = true
                    }
                    return
                }

                print("📦 Image data size: \(data.count) bytes")
                
                // Debug: Show first few bytes of the response
                if data.count < 200 {
                    let dataString = String(data: data, encoding: .utf8) ?? "Unable to decode as UTF-8"
                    print("🔍 DEBUG: Response data (first 200 bytes): \(dataString)")
                } else {
                    let firstBytes = data.prefix(100)
                    let dataString = String(data: firstBytes, encoding: .utf8) ?? "Unable to decode as UTF-8"
                    print("🔍 DEBUG: Response data (first 100 bytes): \(dataString)")
                }

                if let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.loadedUIImage = uiImage
                        self.baseUIImage = uiImage
                        print("✅ Image successfully loaded via UIImage(data:)")
                        print("🧩 baseUIImage set to: \(self.baseUIImage != nil ? "valid" : "nil")")
                    }
                } else if let cgImageSource = CGImageSourceCreateWithData(data as CFData, nil),
                          let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) {
                    let fallbackImage = UIImage(cgImage: cgImage)
                    DispatchQueue.main.async {
                        self.loadedUIImage = fallbackImage
                        self.baseUIImage = fallbackImage
                        print("✅ Image successfully loaded via CGImage fallback")
                        print("🧩 baseUIImage set to: \(self.baseUIImage != nil ? "valid" : "nil")")
                    }
                } else {
                    print("❌ Image decoding failed — neither UIImage nor CGImage succeeded")
                }
            }.resume()
            } else {
                print("🧩 Image already loaded, skipping URL fetch")
            }
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
    
    private func captureUIImageIfNeeded(from url: URL) {
        guard baseUIImage == nil else { return }
        Task { @MainActor in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let ui = UIImage(data: data) {
                    baseUIImage = ui
                }
            } catch {
                print("⚠️ captureUIImageIfNeeded error:", error)
            }
        }
    }
    
    @MainActor
    private func replaceWithEdited(merged: UIImage, overlayPNG: Data, drawingData: Data) async {
        guard !isBusy else { return }
        guard let workOrderId = workOrderId, let itemId = itemId else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let payload = try await StorageManager.shared.uploadEditedImageAdjacent(
                originalURL: imageURL,
                mergedUIImage: merged
            )

            try await WorkOrdersDatabase.shared.replaceItemImageURL(
                workOrderId: workOrderId,
                itemId: itemId,
                oldURL: imageURL.absoluteString,
                newURL: payload.uploadedURL.absoluteString
            )

            await StorageManager.shared.uploadMarkupArtifacts(
                originalURL: imageURL,
                overlayPNG: overlayPNG.isEmpty ? nil : overlayPNG,
                drawingData: drawingData.isEmpty ? nil : drawingData
            )

            let oldPathForDeletion = try StorageManager.shared.storageFolderForSibling(of: imageURL) + "/" + imageURL.lastPathComponent
            await StorageManager.shared.deleteStorageObject(at: oldPathForDeletion)

            lastOldURLForRevert = imageURL.absoluteString
            lastNewURLForRevert = payload.uploadedURL.absoluteString
            lastEditedStoragePath = payload.storagePath

            // Update the displayed image immediately
            loadedUIImage = merged
            baseUIImage = merged
            
            // Update the currentImageURL to point to the new edited image
            // This ensures the viewer shows the edited version
            currentImageURL = payload.uploadedURL
            
            print("🧩 Image replaced successfully - showing merged image")
            print("🧩 New image URL: \(payload.uploadedURL.absoluteString)")
            
            // Notify parent that image was edited
            onImageEdited?()

        } catch {
            print("⚠️ replaceWithEdited error:", error)
        }
    }

    @MainActor
    private func revertToOriginalTapped() async {
        guard !isBusy else { return }
        guard let oldURL = lastOldURLForRevert, let newURL = lastNewURLForRevert else { return }
        guard let workOrderId = workOrderId, let itemId = itemId else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            try await WorkOrdersDatabase.shared.replaceItemImageURL(
                workOrderId: workOrderId,
                itemId: itemId,
                oldURL: newURL,
                newURL: oldURL
            )

            if let editedPath = lastEditedStoragePath {
                await StorageManager.shared.deleteStorageObject(at: editedPath)
            }

            // Reset to original image
            if let originalURL = URL(string: oldURL) {
                // Update currentImageURL to point back to original
                currentImageURL = originalURL
                
                // Reload the original image
                if let data = try? Data(contentsOf: originalURL), let ui = UIImage(data: data) {
                    loadedUIImage = ui
                    baseUIImage = ui
                }
            }
            
            lastOldURLForRevert = nil
            lastNewURLForRevert = nil
            lastEditedStoragePath = nil

        } catch {
            print("⚠️ revertToOriginalTapped error:", error)
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
