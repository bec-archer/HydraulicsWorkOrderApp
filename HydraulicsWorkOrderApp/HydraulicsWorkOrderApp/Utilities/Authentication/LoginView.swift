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
            // Load users database for authentication
            UsersDatabase.shared.loadInitial()
        }
        .padding()
        // END .body
    }

    // ───── PIN Matching Logic ─────
    func handleLogin() {
        // Authenticate against real users in database
        UsersDatabase.shared.authenticateUser(pin: pin) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    if let user = user {
                        // Successful login with real user
                        appState.currentUser = user
                        appState.currentView = .activeWorkOrders
                        loginError = nil
                        isLoggedIn = true
                    } else {
                        // No user found with this PIN
                        loginError = "Invalid PIN"
                    }
                case .failure(let error):
                    // Database error
                    loginError = "Login failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // END
}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    LoginView()
}
