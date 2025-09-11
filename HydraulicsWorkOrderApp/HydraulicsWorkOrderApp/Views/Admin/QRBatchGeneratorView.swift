//
//  Untitled.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/11/25.
//
//
//  QRBatchGeneratorView.swift
//  HydraulicsWorkOrderApp
//
//  Manager/Admin-only tool to generate batches of QR codes and export an 8.5x11 PDF.
//  Uses Core Image for QR generation and PDFKit for sheet output.
//
// ────────────────────────────────────────────────────────────────────────────────
//  IMPORTANT USAGE NOTES
//  - Keep tag ID format consistent with your existing Tag/WO_Item schema.
//  - Default payload: "hwoa:tag:<TAG_ID>". Adjust encodePayload() if needed.
//  - This is a new view; it does not alter any existing UI.
//  - Add navigation entry under Admin tools; guard with your role system.
// ────────────────────────────────────────────────────────────────────────────────

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import CoreImage
import CoreImage.CIFilterBuiltins

// ───── SUPPORTING TYPES ────────────────────────────────────────────────────────

struct QRBatchLayout {
    var pageSize: CGSize = CGSize(width: 612, height: 792) // 8.5x11 @ 72 dpi PDF points
    var margins: EdgeInsets = EdgeInsets(top: 36, leading: 36, bottom: 36, trailing: 36)
    var columns: Int = 3
    var rows: Int = 4
    var qrSidePoints: CGFloat = 72 // 1 inches @ 72 dpi
    var labelFontSize: CGFloat = 12
    var labelHeight: CGFloat = 16
    var gutterH: CGFloat = 18
    var gutterV: CGFloat = 24
}

// ───── MAIN VIEW ───────────────────────────────────────────────────────────────

struct QRBatchGeneratorView: View {
    // Inject your real role from app state / environment
    @State private var currentRole: UserRole = .admin
    
    // Batch parameters
    @State private var prefix: String = "TAG"
    @State private var startNumber: Int = 1
    @State private var count: Int = 12
    
    // Layout parameters (tunable)
    @State private var layout = QRBatchLayout()
    
    // Output
    @State private var generatedPDFURL: URL?
    @State private var isExporting: Bool = false
    @State private var errorMessage: String?
    
    // CI Context
    private let ciContext = CIContext()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ───── ACCESS GATE ─────
            if !isPrivileged {
                Text("Access Restricted")
                    .font(.title2).bold()
                Text("This tool is limited to Managers, Admins, and Superadmins.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                // ───── FORM ─────
                Group {
                    Text("QR Batch Generator")
                        .font(.largeTitle).bold()
                        .padding(.bottom, 4)
                    
                    Text("Generates an 8.5×11 PDF sheet of scannable QR tags for equipment labeling.")
                        .foregroundColor(.secondary)
                    
                    // Batch ID controls
                    HStack(spacing: 12) {
                        TextField("Prefix (e.g., TAG)", text: $prefix)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 180)
                        
                        Stepper("Start #: \(startNumber)", value: $startNumber, in: 1...999_999)
                        Stepper("Count: \(count)", value: $count, in: 1...999)
                    }
                    
                    // Layout controls (basic)
                    HStack(spacing: 12) {
                        Stepper("Columns: \(layout.columns)", value: $layout.columns, in: 1...6)
                        Stepper("Rows: \(layout.rows)", value: $layout.rows, in: 1...12)
                        Stepper("QR side (pts): \(Int(layout.qrSidePoints))", value: $layout.qrSidePoints, in: 96...216, step: 6)
                    }
                    
                    HStack(spacing: 12) {
                        Stepper("H Gutter: \(Int(layout.gutterH))", value: $layout.gutterH, in: 6...48, step: 2)
                        Stepper("V Gutter: \(Int(layout.gutterV))", value: $layout.gutterV, in: 6...48, step: 2)
                        Stepper("Label font: \(Int(layout.labelFontSize))", value: $layout.labelFontSize, in: 8...18)
                    }
                }
                // END form
                
                // ───── ACTIONS ─────
                HStack {
                    Button {
                        generatePDF()
                    } label: {
                        Label("Generate PDF", systemImage: "qrcode")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if let url = generatedPDFURL {
                        ShareLink(item: url, preview: SharePreview("QR Batch Sheet", image: Image(systemName: "doc.richtext")))
                            .buttonStyle(.bordered)
                        
                        Button {
                            // Trigger UIActivityViewController with print option available (AirPrint)
                            isExporting = true
                        } label: {
                            Label("Open in… / Print", systemImage: "printer")
                        }
                        .buttonStyle(.bordered)
                        .sheet(isPresented: $isExporting) {
                            ActivityViewController(items: [url])
                        }
                    }
                }
                // END actions
                
                if let msg = errorMessage {
                    Text(msg)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
        }
        .padding(20)
        // END .body
    }
    
    // ───── PERMISSIONS ─────────────────────────────────────────────────────────
    private var isPrivileged: Bool {
        switch currentRole {
        case .manager, .admin, .superadmin:
            return true
        default:
            return false
        }
    }
    // END permissions
    
    // ───── CORE: PDF GENERATION ────────────────────────────────────────────────
    private func generatePDF() {
        errorMessage = nil
        generatedPDFURL = nil
        
        let ids = buildTagIDs(prefix: prefix, start: startNumber, count: count)
        guard !ids.isEmpty else {
            errorMessage = "No tags to generate."
            return
        }
        
        // Compute how many per page based on layout (rows * columns)
        let perPage = max(layout.rows * layout.columns, 1)
        let pagesNeeded = Int(ceil(Double(ids.count) / Double(perPage)))
        
        // Create a PDF context in memory
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: layout.pageSize), nil)
        
        // Grid metrics
        let contentWidth = layout.pageSize.width - layout.margins.leading - layout.margins.trailing
        let contentHeight = layout.pageSize.height - layout.margins.top - layout.margins.bottom
        let totalGutterW = layout.gutterH * CGFloat(max(layout.columns - 1, 0))
        let totalGutterH = layout.gutterV * CGFloat(max(layout.rows - 1, 0))
        let cellWidth = (contentWidth - totalGutterW) / CGFloat(layout.columns)
        let cellHeight = (contentHeight - totalGutterH) / CGFloat(layout.rows)
        
        let qrSide = min(layout.qrSidePoints, min(cellWidth, cellHeight - layout.labelHeight))
        
        // Render pages
        let filter = CIFilter.qrCodeGenerator()
        filter.correctionLevel = "M" // Medium error correction
        
        for pageIndex in 0..<pagesNeeded {
            UIGraphicsBeginPDFPage()
            guard let ctx = UIGraphicsGetCurrentContext() else { continue }
            ctx.saveGState()
            
            // Page slice
            let start = pageIndex * perPage
            let end = min(start + perPage, ids.count)
            let _ = ids[start..<end]
            
            // Draw header (optional)
            let headerRect = CGRect(x: layout.margins.leading,
                                    y: layout.margins.top - 24,
                                    width: contentWidth,
                                    height: 18)
            let header = "QR Batch • \(prefix) • \(ids.first ?? "") – \(ids.last ?? "")"
            draw(text: header, in: headerRect, font: .systemFont(ofSize: 12), align: .left)
            
            // Draw grid
            var idxOnPage = 0
            for r in 0..<layout.rows {
                for c in 0..<layout.columns {
                    let globalIndex = start + idxOnPage
                    guard globalIndex < end else { break }
                    let tagID = ids[globalIndex]
                    
                    // Cell origin
                    let x = layout.margins.leading + CGFloat(c) * (cellWidth + layout.gutterH)
                    let y = layout.margins.top + CGFloat(r) * (cellHeight + layout.gutterV)
                    let cellRect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                    
                    // QR image frame
                    let qrX = cellRect.midX - qrSide/2
                    let qrY = cellRect.minY + (cellHeight - layout.labelHeight - qrSide)/2
                    let qrRect = CGRect(x: qrX, y: qrY, width: qrSide, height: qrSide)
                    
                    // Label frame
                    let labelRect = CGRect(x: cellRect.minX, y: qrRect.maxY + 4, width: cellWidth, height: layout.labelHeight)
                    
                    // Generate & draw QR
                    if let cg = makeQRCodeCGImage(for: tagID, using: filter) {
                        ctx.interpolationQuality = .none // keep edges crisp
                        ctx.draw(cg, in: qrRect)
                    }
                    
                    // Draw text label (human readable)
                    draw(text: tagID, in: labelRect, font: .monospacedSystemFont(ofSize: layout.labelFontSize, weight: .regular), align: .center)
                    
                    idxOnPage += 1
                }
            }
            ctx.restoreGState()
        }
        
        UIGraphicsEndPDFContext()
        
        // Save to temporary file
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("QR_Batch_\(prefix)_\(startNumber)_\(count).pdf")
        do {
            try pdfData.write(to: tmp, options: .atomic)
            generatedPDFURL = tmp
        } catch {
            errorMessage = "Failed to write PDF: \(error.localizedDescription)"
        }
    }
    // END core
    
    // ───── HELPERS: TAGS & QR ─────────────────────────────────────────────────
    
    /// Build sequential tag IDs: PREFIX-000001… with fixed width (6). Adjust width if you expect > 999,999.
    private func buildTagIDs(prefix: String, start: Int, count: Int) -> [String] {
        guard count > 0, start > 0 else { return [] }
        let width = 6
        return (0..<count).map { i in
            let n = start + i
            return "\(prefix)-" + String(format: "%0\(width)d", n)
        }
    }
    
    /// Encode payload for the QR symbol. Keep stable; scanners should resolve tag → WO_Item server-side.
    private func encodePayload(for tagID: String) -> Data {
        // Example: "hwoa:tag:TAG-000123"
        let s = "hwoa:tag:\(tagID)"
        return Data(s.utf8)
    }
    
    /// Generate a crisp QR as CGImage using Core Image.
    private func makeQRCodeCGImage(for tagID: String, using filter: CIQRCodeGenerator) -> CGImage? {
        filter.message = encodePayload(for: tagID)
        guard let output = filter.outputImage else { return nil }
        // Scale up to a reasonable pixel size to keep edges sharp when drawn into PDF
        let scale: CGFloat = 8
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return ciContext.createCGImage(transformed, from: transformed.extent)
    }
    
    /// Draw simple strings into PDF graphics context.
    private func draw(text: String, in rect: CGRect, font: UIFont, align: NSTextAlignment) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: style
        ]
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }
    // END helpers
}
// END view

// ───── UIActivityViewController WRAPPER ───────────────────────────────────────

struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
// END wrapper

// ───── PREVIEW ────────────────────────────────────────────────────────────────

#Preview {
    QRBatchGeneratorView()
        .frame(minWidth: 480, minHeight: 360)
}
