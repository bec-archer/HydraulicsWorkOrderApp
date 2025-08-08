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
    @State private var pin: String = ""
    @State private var loginError: String?
    @State private var isLoggedIn = false
    @State private var userRole: UserRole?

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
            if let role = userRole {
                switch role {
                case .tech, .manager:
                    Text("🚧 WorkOrdersView Coming Soon")
                case .admin, .superadmin:
                    Text("⚙️ SettingsView Coming Soon")
                }
            }
        }

        .onAppear {
            if DevSettingsManager.shared.skipLogin {
                self.userRole = .superadmin
                self.isLoggedIn = true
            }
        }
        .padding()
        // END .body
    }

    // ───── PIN Matching Logic ─────
    func handleLogin() {
        switch pin {
        case "1234":
            userRole = .tech
        case "2345":
            userRole = .manager
        case "5678":
            userRole = .admin
        case "0000":
            userRole = .superadmin
        default:
            loginError = "Invalid PIN"
            return
        }

        loginError = nil
        isLoggedIn = true
    }

    // END
}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    LoginView()
}
