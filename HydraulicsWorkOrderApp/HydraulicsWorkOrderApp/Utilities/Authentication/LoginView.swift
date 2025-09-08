//
//  LoginView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 LoginView.swift
// PIN-based login screen for all user roles
// ─────────────────────────────────────────────────────────────

import SwiftUI

// MARK: - LoginView

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var pin: String = ""
    @State private var loginError: String?
    @State private var isLoggedIn = false

    var body: some View {
        VStack(spacing: 24) {
            Text("🔐 Enter PIN")
                .font(.largeTitle)

            SecureField("4–8 digit PIN", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title2)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .frame(width: 240)

            if let error = loginError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            Button("Login") {
                handleLogin()
            }
            .padding()
            .frame(width: 200)
            .background(Color.yellow)
            .foregroundColor(.black)
            .cornerRadius(12)

        }
        .fullScreenCover(isPresented: $isLoggedIn) {
            SimpleRouterView()
                .environmentObject(appState)
        }

        .onAppear {
            // LoginView only shows when dev bypass is disabled
            // No auto-login needed here
        }
        .padding()
        // END .body
    }

    // ───── PIN Matching Logic ─────
    func handleLogin() {
        var userRole: UserRole?
        var userName: String
        
        switch pin {
        case "1234":
            userRole = .tech
            userName = "Tech User"
        case "2345":
            userRole = .manager
            userName = "Manager User"
        case "5678":
            userRole = .admin
            userName = "Admin User"
        case "0000":
            userRole = .superadmin
            userName = "Super Admin"
        default:
            loginError = "Invalid PIN"
            return
        }

        // Update AppState with user info
        if let role = userRole {
            appState.currentUserRole = role
            appState.currentUserName = userName
            appState.currentView = .activeWorkOrders
            
            loginError = nil
            isLoggedIn = true
        }
    }

    // END
}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    LoginView()
}
