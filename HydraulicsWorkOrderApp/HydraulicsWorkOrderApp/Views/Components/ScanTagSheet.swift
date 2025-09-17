//
//  ScanTagSheet.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/17/25.
//
// File: Views/Shared/QR/ScanTagSheet.swift
// Purpose: Permission gate + lifecycle safe start/stop.
// ───── ScanTagSheet ─────

import SwiftUI
import AVFoundation

struct ScanTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scanned: String? = nil
    @State private var cameraAuthorized = false

    var onScan: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Scan QR Code").font(.headline)
            ZStack {
                if cameraAuthorized {
                    QRScannerView(
                        isPresented: .constant(true),
                        onCodeScanned: { value in
                            onScan(value)
                            dismiss()
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.yellow, lineWidth: 2))
                    .frame(maxWidth: 420, maxHeight: 420) // ensure non-zero
                } else {
                    VStack(spacing: 8) {
                        Text("Camera permission needed to scan tags.")
                        Button("Open Settings") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding()
                }
            }
            Button("Cancel") { dismiss() }
        }
        .padding()
        .onAppear { requestCameraIfNeeded() }
    }

    private func requestCameraIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { self.cameraAuthorized = granted }
            }
        case .denied, .restricted:
            cameraAuthorized = false
        @unknown default:
            cameraAuthorized = false
        }
    }
}

// ───── Preview ─────
struct ScanTagSheet_Previews: PreviewProvider {
    static var previews: some View {
        ScanTagSheet { _ in }
            .frame(width: 500, height: 600)
    }
}
// --- END block 2 ---
