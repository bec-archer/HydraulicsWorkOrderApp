//
//  QRBatchReservation.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/11/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import CryptoKit

// ───── MODEL ───────────────────────────────────────────────────────────────────

struct QRBatchReservation: Codable, Identifiable {
    var id: String               // batchId (UUID string)
    var prefix: String
    var startNumber: Int
    var count: Int
    var rangeStart: String       // e.g., "TAG-000123"
    var rangeEnd: String         // e.g., "TAG-000234"
    var tagIds: [String]         // limited sizes recommended (<= 200)
    var pdfChecksumSHA256: String
    var createdAt: Date
    var createdById: String
    var createdByName: String
}

// ───── MANAGER ────────────────────────────────────────────────────────────────

final class BatchReservationManager: ObservableObject {
    
    static let shared = BatchReservationManager()
    private let db = Firestore.firestore()
    
    // Compute SHA256 for a file on disk (PDF)
    private func sha256(ofFile url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Reserve a batch of tag IDs before printing
    func reserveBatch(
        prefix: String,
        startNumber: Int,
        count: Int,
        pdfURL: URL,
        createdBy: User
    ) async throws -> QRBatchReservation {
        
        let batchId = UUID().uuidString
        let rangeStart = "\(prefix)-\(String(format: "%06d", startNumber))"
        let rangeEnd = "\(prefix)-\(String(format: "%06d", startNumber + count - 1))"
        
        // Generate tag IDs
        let tagIds = (startNumber..<(startNumber + count)).map { num in
            "\(prefix)-\(String(format: "%06d", num))"
        }
        
        // Compute PDF checksum
        let pdfChecksum = try sha256(ofFile: pdfURL)
        
        // Create reservation
        let reservation = QRBatchReservation(
            id: batchId,
            prefix: prefix,
            startNumber: startNumber,
            count: count,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            tagIds: tagIds,
            pdfChecksumSHA256: pdfChecksum,
            createdAt: Date(),
            createdById: createdBy.id,
            createdByName: createdBy.displayName
        )
        
        // Reserve in Firestore
        try db.collection("qrReservations").document(batchId).setData(from: reservation)
        
        // Mark individual tags as reserved
        let batch = db.batch()
        for tagId in tagIds {
            let tagRef = db.collection("tagReservations").document(tagId)
            batch.setData([
                "reserved": true,
                "batchId": batchId,
                "reservedAt": Timestamp(date: Date()),
                "byUserId": createdBy.id,
                "byUserName": createdBy.displayName
            ], forDocument: tagRef)
        }
        
        try await batch.commit()
        
        return reservation
    }
    
    // Check if a tag ID is already reserved
    func isTagReserved(_ tagId: String) async throws -> Bool {
        let doc = try await db.collection("tagReservations").document(tagId).getDocument()
        return doc.exists && (doc.data()?["reserved"] as? Bool == true)
    }
    
    // Get all reservations for a user
    func getReservations(for userId: String) async throws -> [QRBatchReservation] {
        let snapshot = try await db.collection("qrReservations")
            .whereField("createdById", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: QRBatchReservation.self)
        }
    }
}

// ───── VIEW ───────────────────────────────────────────────────────────────────

struct QRBatchReservationView: View {
    @StateObject private var reservationManager = BatchReservationManager.shared
    @EnvironmentObject private var appState: AppState
    @State private var reservations: [QRBatchReservation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading reservations...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if reservations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No QR Batch Reservations")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Reservations will appear here after you generate QR batches.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(reservations) { reservation in
                        ReservationRowView(reservation: reservation)
                    }
                }
            }
            .navigationTitle("QR Batch Reservations")
            .task {
                await loadReservations()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func loadReservations() async {
        guard let currentUser = appState.currentUser else { return }
        
        isLoading = true
        do {
            reservations = try await reservationManager.getReservations(for: currentUser.id)
        } catch {
            errorMessage = "Failed to load reservations: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct ReservationRowView: View {
    let reservation: QRBatchReservation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(reservation.prefix)-\(String(format: "%06d", reservation.startNumber))")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(reservation.count) tags")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text("Range: \(reservation.rangeStart) - \(reservation.rangeEnd)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Created: \(reservation.createdAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("by \(reservation.createdByName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// ───── PREVIEW ─────
#Preview {
    QRBatchReservationView()
        .environmentObject(AppState.shared)
}