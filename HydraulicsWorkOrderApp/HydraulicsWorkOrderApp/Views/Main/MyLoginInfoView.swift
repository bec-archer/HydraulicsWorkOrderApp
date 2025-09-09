//
//  MyLoginInfoView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//

import SwiftUI

struct MyLoginInfoView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentPin: String = ""
    @State private var newPin: String = ""
    @State private var confirmPin: String = ""
    @State private var showChangePin = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // ───── User Info Header ─────
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text(appState.currentUserName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(appState.currentUserRole.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                .padding(.top)
                
                // ───── Current PIN Info ─────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Login PIN")
                        .font(.headline)
                    
                    HStack {
                        Text(currentPin.isEmpty ? "Using default PIN" : "••••••••")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Change PIN") {
                            showChangePin = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // ───── Change PIN Form ─────
                if showChangePin {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Change Your PIN")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            SecureField("New PIN (4-8 digits)", text: $newPin)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                            
                            SecureField("Confirm New PIN", text: $confirmPin)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                showChangePin = false
                                newPin = ""
                                confirmPin = ""
                                errorMessage = nil
                                successMessage = nil
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Save PIN") {
                                saveNewPin()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newPin.isEmpty || confirmPin.isEmpty || isLoading)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        if let success = successMessage {
                            Text(success)
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // ───── Default PINs Info ─────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default PINs by Role")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Tech:")
                            Spacer()
                            Text("1234")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Manager:")
                            Spacer()
                            Text("2345")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Admin:")
                            Spacer()
                            Text("5678")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Super Admin:")
                            Spacer()
                            Text("0000")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("My Login Info")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadCurrentUserInfo()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentUserInfo() {
        // Load current user's PIN from AppState
        if let user = appState.currentUser {
            currentPin = user.pin ?? ""
        } else {
            currentPin = ""
        }
    }
    
    private func saveNewPin() {
        // Validate PIN
        guard newPin.count >= 4 && newPin.count <= 8 else {
            errorMessage = "PIN must be 4-8 digits"
            return
        }
        
        guard newPin.allSatisfy({ $0.isNumber }) else {
            errorMessage = "PIN must contain only numbers"
            return
        }
        
        guard newPin == confirmPin else {
            errorMessage = "PINs do not match"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // Save PIN to database
        guard var user = appState.currentUser else {
            errorMessage = "No user logged in"
            isLoading = false
            return
        }
        
        // Update user's PIN
        user.pin = newPin
        user.updatedAt = Date()
        
        // Save to database
        UsersDatabase.shared.update(user)
        
        // Update AppState
        appState.currentUser = user
        
        // Update local state
        currentPin = newPin
        newPin = ""
        confirmPin = ""
        showChangePin = false
        successMessage = "PIN updated successfully!"
        isLoading = false
        
        // Clear success message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            successMessage = nil
        }
    }
}

// MARK: - Preview
#Preview {
    MyLoginInfoView()
        .environmentObject(AppState.shared)
}
