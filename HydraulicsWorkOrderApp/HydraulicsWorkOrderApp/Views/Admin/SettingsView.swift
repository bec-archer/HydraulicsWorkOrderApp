//
//  SettingsView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/12/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 SettingsView.swift
// Admin/Dev toggles for bypassing login, scan enforcement, sample reload
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct SettingsView: View {
    @ObservedObject var devSettings = DevSettingsManager.shared

    // ───── PIN Prompt State ─────
    @State private var showPinPrompt = false
    @State private var enteredPin = ""
    @State private var pinError: String?
    @State private var pendingBypassValue: Bool = false


    var body: some View {
        Form {
            // ───── Developer Settings ─────
            Section(header: Text("Developer Settings")) {
                
                // 🔐 PIN-protected toggle for bypass login
                Toggle("Bypass Login Screen", isOn: Binding(
                    get: { devSettings.skipLogin },
                    set: { newValue in
                        showPinPrompt = true
                        pendingBypassValue = newValue
                    }
                ))
                
                Toggle("Bypass Tag Scan Requirement", isOn: $devSettings.skipTagScan)

                // 🔐 Enable anonymous Firebase Auth so image uploads work with strict rules
                Toggle("Enable Anonymous Firebase Auth", isOn: $devSettings.enableAnonAuth)
                    .accessibilityHint("Turn on to sign in anonymously at launch so Firebase Storage uploads are allowed")
            }
        }
        .navigationTitle("Settings")
        
        // ───── PIN Entry Sheet ─────
        .sheet(isPresented: $showPinPrompt) {
            VStack(spacing: 16) {

                // Title
                Text("Super Admin PIN Required")
                    .font(.title2.weight(.semibold))
                    .padding(.top, 8)

                // Secure PIN input (4–8 digits)
                SecureField("Enter 4–8 digit PIN", text: $enteredPin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode) // shows numeric pad on iPad
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                // Error feedback (if any)
                if let pinError {
                    Text(pinError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                // Actions
                HStack {
                    Button("Cancel") {
                        // Do not change the setting; just dismiss
                        showPinPrompt = false
                        enteredPin = ""
                        pinError = nil
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 24)

                    Button("Confirm") {
                        // ───── SuperAdmin validation + update ─────
                        let ok = devSettings.setBypassLogin(pendingBypassValue, pin: enteredPin)
                        if ok {
                            // Success: the underlying Published skipLogin is updated & persisted
                            showPinPrompt = false
                            pinError = nil
                        } else {
                            // Failure: keep sheet open and show error
                            pinError = "Incorrect PIN. Try again."
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
            .padding()
            .onAppear {
                // Reset every time the sheet is shown
                enteredPin = ""
                pinError = nil
            }
        }
        // END sheet

    }
}


// END .body
// END struct

// ───── Preview Template ─────
#Preview {
    NavigationStack {
        SettingsView()
    }
}
