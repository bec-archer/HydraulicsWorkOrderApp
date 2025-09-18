//
//  QRScannerView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Assistant on 1/8/25.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - QR Scanner View
@MainActor
struct QRScannerView: View {
    @Binding var isPresented: Bool
    let onCodeScanned: (String) -> Void
    
    @State private var isScanning = false
    @State private var scannedCode: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera view
                QRScannerViewController(
                    isScanning: $isScanning,
                    onCodeScanned: { code in
                        scannedCode = code
                        onCodeScanned(code)
                        isPresented = false
                    }
                )
                .ignoresSafeArea()
                .onAppear {            // ← ADD
                    isScanning = true   // ← ADD
                }                       // ← ADD
                .onDisappear {          // ← ADD
                    isScanning = false  // ← ADD
                }
                
                // Overlay with scanning frame
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Text("Position QR code within the frame")
                            .foregroundColor(.white)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        // Scanning frame
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.yellow, lineWidth: 3)
                            .frame(width: 250, height: 250)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.7))
                    )
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - QR Scanner View Controller
struct QRScannerViewController: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    let onCodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerVC {
        let controller = QRScannerVC()
        controller.onCodeScanned = onCodeScanned
        return controller
    }
    

    func updateUIViewController(_ uiViewController: QRScannerVC, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            // Do NOT force-stop here; stopping is handled by viewWillDisappear to
            // avoid a race that produces a blank preview.
        }
    }
}

// MARK: - QR Scanner View Controller Implementation
class QRScannerVC: UIViewController {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onCodeScanned: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreviewLayerFrame()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { _ in
            self.updatePreviewLayerFrame()
        }, completion: nil)
    }
    
    
    private func setupCamera() {
        // ───── Check Camera Permission First ─────
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCameraSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupCameraSession()
                    } else {
                        print("❌ Camera access denied by user")
                    }
                }
            }
        case .denied, .restricted:
            print("❌ Camera access denied or restricted")
        @unknown default:
            print("❌ Unknown camera authorization status")
        }
    }
    
    private func setupCameraSession() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ No video capture device available")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("❌ Failed to create video input: \(error)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("❌ Cannot add video input to capture session")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417]
        } else {
            print("❌ Cannot add metadata output to capture session")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        // ───── Mirror the preview to match user expectation ─────
        previewLayer.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        view.layer.addSublayer(previewLayer)
        
        // ───── Set initial orientation ─────
        updatePreviewLayerFrame()
        
        print("✅ Camera session setup completed successfully")
    }
    
    func startScanning() {
        guard let captureSession = captureSession else {
            print("❌ Cannot start scanning - capture session not initialized")
            return
        }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopScanning() {
        guard let captureSession = captureSession else { return }
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // ───── Update Preview Layer Frame and Orientation ─────
    private func updatePreviewLayerFrame() {
        guard let previewLayer = previewLayer else { return }
        
        // Update frame to match current view bounds
        previewLayer.frame = view.layer.bounds
        
        // Update connection orientation based on device orientation
        if let connection = previewLayer.connection {
            let orientation = UIDevice.current.orientation
            if #available(iOS 17.0, *) {
                // Use the new videoRotationAngle property for iOS 17+
                switch orientation {
                case .portrait:
                    connection.videoRotationAngle = 0
                case .portraitUpsideDown:
                    connection.videoRotationAngle = 180
                case .landscapeLeft:
                    connection.videoRotationAngle = 90
                case .landscapeRight:
                    connection.videoRotationAngle = 270
                default:
                    // Use current interface orientation as fallback
                    if let windowScene = view.window?.windowScene {
                        switch windowScene.interfaceOrientation {
                        case .portrait:
                            connection.videoRotationAngle = 0
                        case .portraitUpsideDown:
                            connection.videoRotationAngle = 180
                        case .landscapeLeft:
                            connection.videoRotationAngle = 270
                        case .landscapeRight:
                            connection.videoRotationAngle = 90
                        default:
                            connection.videoRotationAngle = 0
                        }
                    }
                }
            } else {
                // Use the deprecated videoOrientation property for iOS 16 and earlier
                switch orientation {
                case .portrait:
                    connection.videoOrientation = .portrait
                case .portraitUpsideDown:
                    connection.videoOrientation = .portraitUpsideDown
                case .landscapeLeft:
                    connection.videoOrientation = .landscapeRight
                case .landscapeRight:
                    connection.videoOrientation = .landscapeLeft
                default:
                    // Use current interface orientation as fallback
                    if let windowScene = view.window?.windowScene {
                        switch windowScene.interfaceOrientation {
                        case .portrait:
                            connection.videoOrientation = .portrait
                        case .portraitUpsideDown:
                            connection.videoOrientation = .portraitUpsideDown
                        case .landscapeLeft:
                            connection.videoOrientation = .landscapeLeft
                        case .landscapeRight:
                            connection.videoOrientation = .landscapeRight
                        default:
                            connection.videoOrientation = .portrait
                        }
                    }
                }
            }
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension QRScannerVC: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Call the completion handler
            onCodeScanned?(stringValue)
        }
    }
}

// MARK: - Preview
#Preview {
    QRScannerView(
        isPresented: .constant(true),
        onCodeScanned: { code in
            print("Scanned code: \(code)")
        }
    )
}
