//
//  LoginView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 LoginView.swift
// iPad/iPhone unlock screen-style PIN login for all user roles
// ─────────────────────────────────────────────────────────────

import SwiftUI

// MARK: - LoginView

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var pin: String = ""
    @State private var loginError: String?
    @State private var isLoggedIn = false
    @State private var showError = false
    @State private var isLoadingUsers = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // ───── Background Gradient ─────
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#F5F5F7"),
                        Color(hex: "#E5E5E7")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // ───── App Icon/Logo Section ─────
                    VStack(spacing: 20) {
                        // App icon placeholder - using a gear icon for hydraulics theme
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(Color(hex: "#FFC500"))
                            .padding(.bottom, 10)
                        
                        Text("Hydraulics Work Order")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.primary)
                        
                        Text("Enter Passcode")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 40)
                        
                        // ───── Loading Indicator ─────
                        if isLoadingUsers {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading users...")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    
                    // ───── PIN Dots Display ─────
                    HStack(spacing: 16) {
                        ForEach(0..<8, id: \.self) { index in
                            Circle()
                                .fill(index < pin.count ? Color(hex: "#FFC500") : Color.gray.opacity(0.3))
                                .frame(width: 16, height: 16)
                                .scaleEffect(index < pin.count ? 1.0 : 0.8)
                                .animation(.easeInOut(duration: 0.2), value: pin.count)
                        }
                    }
                    .padding(.bottom, 60)
                    
                    // ───── Error Message ─────
                    if showError {
                        Text(loginError ?? "Invalid PIN")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.bottom, 20)
                            .transition(.opacity.combined(with: .scale))
                    }
                    
                    // ───── Done Button (appears when PIN is 4+ digits) ─────
                    if pin.count >= 4 {
                        Button("Done") {
                            handleLogin()
                        }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isLoadingUsers ? .gray : Color(hex: "#FFC500"))
                        .padding(.bottom, 20)
                        .disabled(isLoadingUsers)
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    Spacer()
                    
                    // ───── Number Pad ─────
                    VStack(spacing: 20) {
                        // Row 1: 1, 2, 3
                        HStack(spacing: 40) {
                            NumberButton(number: "1", action: { addDigit("1") })
                            NumberButton(number: "2", action: { addDigit("2") })
                            NumberButton(number: "3", action: { addDigit("3") })
                        }
                        
                        // Row 2: 4, 5, 6
                        HStack(spacing: 40) {
                            NumberButton(number: "4", action: { addDigit("4") })
                            NumberButton(number: "5", action: { addDigit("5") })
                            NumberButton(number: "6", action: { addDigit("6") })
                        }
                        
                        // Row 3: 7, 8, 9
                        HStack(spacing: 40) {
                            NumberButton(number: "7", action: { addDigit("7") })
                            NumberButton(number: "8", action: { addDigit("8") })
                            NumberButton(number: "9", action: { addDigit("9") })
                        }
                        
                        // Row 4: Empty, 0, Delete
                        HStack(spacing: 40) {
                            // Empty space for alignment
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 80, height: 80)
                            
                            NumberButton(number: "0", action: { addDigit("0") })
                            
                            // Delete button
                            Button(action: deleteDigit) {
                                Image(systemName: "delete.left")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.primary)
                                    .frame(width: 80, height: 80)
                                    .background(
                                        Circle()
                                            .fill(Color.clear)
                                    )
                            }
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .fullScreenCover(isPresented: $isLoggedIn) {
            SimpleRouterView()
                .environmentObject(appState)
        }
        .onAppear {
            // LoginView only shows when dev bypass is disabled
            // Load users database for authentication
            loadUsersForAuthentication()
        }
        // END .body
    }

    // ───── User Loading ─────
    private func loadUsersForAuthentication() {
        isLoadingUsers = true
        UsersDatabase.shared.fetchAllUsers { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    print("🔐 Users loaded for authentication: \(users.count) users")
                    isLoadingUsers = false
                case .failure(let error):
                    print("❌ Failed to load users for authentication: \(error.localizedDescription)")
                    loginError = "Failed to load users"
                    showError = true
                    isLoadingUsers = false
                }
            }
        }
    }
    
    // ───── PIN Input Handlers ─────
    private func addDigit(_ digit: String) {
        if pin.count < 8 {
            pin += digit
            showError = false
        }
    }
    
    private func deleteDigit() {
        if !pin.isEmpty {
            pin.removeLast()
            showError = false
        }
    }
    
    // ───── PIN Matching Logic ─────
    func handleLogin() {
        // Don't allow login while users are still loading
        if isLoadingUsers {
            loginError = "Loading users, please wait..."
            showError = true
            return
        }
        
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
                        showError = false
                        isLoggedIn = true
                    } else {
                        // No user found with this PIN
                        loginError = "Invalid PIN"
                        showError = true
                        pin = "" // Clear PIN on error
                    }
                case .failure(let error):
                    // Database error
                    loginError = "Login failed: \(error.localizedDescription)"
                    showError = true
                    pin = "" // Clear PIN on error
                }
            }
        }
    }
    // END
}

// ───── NumberButton Component ─────
struct NumberButton: View {
    let number: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.primary)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    LoginView()
}
