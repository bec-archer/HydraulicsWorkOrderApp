//
//  TagScanningView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Assistant on 1/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 TagScanningView.swift
// Tag scanning view that uses QRScannerView to scan asset tags and navigate to work order item detail
// ─────────────────────────────────────────────────────────────

import SwiftUI
import Foundation

// MARK: - TagScanningView
struct TagScanningView: View {
    // MARK: - Properties
    @Binding var isPresented: Bool
    @EnvironmentObject private var appState: AppState
    
    // MARK: - State
    @State private var showQRScanner = false
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var showError = false
    
    // MARK: - Services
    private let workOrdersDB = WorkOrdersDatabase.shared
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // ───── Header Section ─────
                VStack(spacing: 16) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#FFC500"))
                    
                    Text("Scan Asset Tag")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    
                    Text("Position the QR code within the camera frame to find the associated work order item")
                        .font(.subheadline)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // ───── Instructions Section ─────
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions:")
                        .font(.headline)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionRow(
                            icon: "1.circle.fill",
                            text: "Tap the 'Scan QR Code' button below"
                        )
                        
                        InstructionRow(
                            icon: "2.circle.fill",
                            text: "Position the asset tag QR code within the camera frame"
                        )
                        
                        InstructionRow(
                            icon: "3.circle.fill",
                            text: "The app will automatically find and display the work order item details"
                        )
                    }
                }
                .padding()
                .background(ThemeManager.shared.cardBackground)
                .cornerRadius(ThemeManager.shared.cardCornerRadius)
                .shadow(
                    color: ThemeManager.shared.cardShadowColor.opacity(ThemeManager.shared.cardShadowOpacity),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                
                Spacer()
                
                // ───── Action Buttons ─────
                VStack(spacing: 16) {
                    // Scan QR Code Button
                    Button(action: {
                        showQRScanner = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                            Text("Scan QR Code")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#FFC500"))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Cancel Button
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(ThemeManager.shared.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ThemeManager.shared.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ThemeManager.shared.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Tag Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView(
                isPresented: $showQRScanner,
                onCodeScanned: { scannedCode in
                    handleScannedCode(scannedCode)
                }
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
                searchError = nil
            }
        } message: {
            Text(searchError ?? "An unknown error occurred")
        }
    }
    
    // MARK: - Private Methods
    private func handleScannedCode(_ code: String) {
        print("🔍 DEBUG: TagScanningView received scanned code: \(code)")
        
        // Validate the scanned code
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchError = "Invalid QR code: Empty or whitespace only"
            showError = true
            return
        }
        
        // Start searching
        isSearching = true
        searchError = nil
        
        // Search for the work order item by tag ID
        workOrdersDB.findWorkOrderItemByTagId(code) { result in
            Task { @MainActor in
                isSearching = false
                
                switch result {
                case .success(let (workOrder, item, itemIndex)):
                    print("✅ DEBUG: Found work order item for tag \(code)")
                    print("✅ DEBUG: Work Order: \(workOrder.workOrderNumber)")
                    print("✅ DEBUG: Item: \(item.type)")
                    print("✅ DEBUG: Item Index: \(itemIndex)")
                    
                    // Navigate to the work order item detail view
                    appState.navigateToWorkOrderItemDetail(workOrder, item: item, itemIndex: itemIndex)
                    
                    // Close the scanning view
                    isPresented = false
                    
                case .failure(let error):
                    print("❌ DEBUG: Failed to find work order item for tag \(code): \(error)")
                    searchError = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - InstructionRow Component
struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(hex: "#FFC500"))
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(ThemeManager.shared.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    TagScanningView(isPresented: .constant(true))
        .environmentObject(AppState.shared)
}
