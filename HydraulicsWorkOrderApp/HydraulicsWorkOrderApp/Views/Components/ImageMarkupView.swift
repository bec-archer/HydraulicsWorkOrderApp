//
//  ImageMarkupView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/18/25.
//
// PURPOSE: Non-destructive PencilKit editor overlaying a UIImage.
// No existing UI is changed; this view is only presented modally.

import SwiftUI
import PencilKit

struct PKCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let toolPicker: PKToolPicker

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        canvasView.drawingPolicy = .anyInput
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        DispatchQueue.main.async { canvasView.becomeFirstResponder() }
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) { }
}

struct ImageMarkupView: View {
    let baseImage: UIImage
    let onCancel: () -> Void
    let onSave: (_ merged: UIImage, _ overlayPNG: Data, _ drawingData: Data) -> Void

    @State private var canvasView = PKCanvasView()
    private let toolPicker = PKToolPicker()

    var body: some View {
        VStack(spacing: 0) {
            // simple toolbar
            HStack(spacing: 16) {
                Button { canvasView.tool = PKInkingTool(.pen, color: .red, width: 5) } label: { Image(systemName: "pencil.tip") }
                Button { canvasView.tool = PKInkingTool(.marker, color: UIColor.yellow.withAlphaComponent(0.6), width: 18) } label: { Image(systemName: "highlighter") }
                Button { canvasView.tool = PKEraserTool(.vector) } label: { Image(systemName: "eraser") }
                Button { canvasView.drawing = PKDrawing() } label: { Image(systemName: "trash") }
                Spacer()
            }
            .font(.title2)
            .padding()
            .background(.ultraThinMaterial)

            GeometryReader { _ in
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: baseImage)
                        .resizable()
                        .scaledToFit()
                        .background(Color.black)
                    PKCanvasRepresentable(canvasView: $canvasView, toolPicker: toolPicker)
                        .allowsHitTesting(true)
                        .background(Color.clear)
                }
            }

            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                Spacer()
                Button("Save") { exportAndSave() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .onAppear {
            canvasView.tool = PKInkingTool(.pen, color: .red, width: 5)
        }
    }

    private func exportAndSave() {
        let drawing = canvasView.drawing
        let drawingData = drawing.dataRepresentation()
        let overlay = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
        let overlayPNG = overlay.pngData() ?? Data()
        let merged = baseImage.merging(overlayImage: overlay)
        onSave(merged, overlayPNG, drawingData)
    }
}

fileprivate extension UIImage {
    func merging(overlayImage: UIImage) -> UIImage {
        let size = self.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            self.draw(in: CGRect(origin: .zero, size: size))
            overlayImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    ImageMarkupView(
        baseImage: UIImage(systemName: "photo")!,
        onCancel: {},
        onSave: {_,_,_ in}
    )
}
