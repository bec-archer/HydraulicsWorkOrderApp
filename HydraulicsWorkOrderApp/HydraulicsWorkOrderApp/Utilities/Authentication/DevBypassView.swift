//
//  DevBypassView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 1/9/25.
//

import SwiftUI

// ─────────────────────────────────────────────────────────────
// 📄 DevBypassView.swift
// Handles dev bypass authentication by creating a dev user
// before showing the main app interface
// ─────────────────────────────────────────────────────────────

struct DevBypassView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isAuthenticated = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                SimpleRouterView()
            } else {
                // Show loading while setting up dev user
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Setting up development environment...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            setupDevUser()
        }
    }
    
    private func setupDevUser() {
        // Create dev user immediately
        appState.currentUser = User(
            id: "dev-user-id",
            displayName: "Dev User",
            phoneE164: nil,
            role: .superadmin,
            isActive: true,
            pin: nil,
            createdAt: Date(),
            updatedAt: Date(),
            createdByUserId: nil,
            updatedByUserId: nil
        )
        
        // Set initial view
        appState.currentView = .activeWorkOrders
        
        // Mark as authenticated
        isAuthenticated = true
        
        print("🔍 DEBUG: Dev user created and authenticated")
    }
}

#Preview {
    DevBypassView()
        .environmentObject(AppState.shared)
}
