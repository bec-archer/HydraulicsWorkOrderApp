//
//  OfflineStatusModifier.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/18/25.
//


// OfflineStatusModifier.swift

import SwiftUI

struct OfflineStatusModifier: ViewModifier {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var offlineManager = OfflineManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    Spacer()
                    if !networkMonitor.isConnected {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("Offline Mode - Changes will sync when connection is restored")
                            
                            if offlineManager.pendingChanges > 0 {
                                Text("(\(offlineManager.pendingChanges) pending)")
                                    .bold()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.orange)
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    }
                }
            )
    }
}

extension View {
    func withOfflineStatus() -> some View {
        self.modifier(OfflineStatusModifier())
    }
}