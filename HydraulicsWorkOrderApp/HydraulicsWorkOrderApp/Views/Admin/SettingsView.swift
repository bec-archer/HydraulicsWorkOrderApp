//
//  SettingsView 2.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//


// ───── SETTINGS VIEW ─────
import SwiftUI

/// Admin/SuperAdmin-only settings panel.
/// Provides access to sync health, dropdowns, user manager,
/// and SuperAdmin dev toggles (login enforcement, scan enforcement, sample reset).
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // ───── BODY ─────
        NavigationStack {
            List {
                // Admin + SuperAdmin tools
                if appState.isAdmin || appState.isSuperAdmin {
                    NavigationLink("Manage Users", destination: UserManagerView()
                        .environmentObject(appState))

                    NavigationLink("Sync Status", destination: SyncStatusView()
                        .environmentObject(appState))
                    
                    NavigationLink("Completion Requirements", destination: CompletionRequirementsSettingsView()
                        .environmentObject(appState))
                }

                // SuperAdmin-only dev toggles
                if appState.isSuperAdmin {
                    Section("Developer Toggles") {
                        Toggle("Disable Login Screen", isOn: Binding(
                            get: { DevSettingsManager.shared.skipLogin },
                            set: { DevSettingsManager.shared.skipLogin = $0 }
                        ))
                        Toggle("Bypass Tag Scan Enforcement", isOn: Binding(
                            get: { DevSettingsManager.shared.skipTagScan },
                            set: { DevSettingsManager.shared.skipTagScan = $0 }
                        ))
                        Button("Reload Sample Data") {
                            // TODO: wire sample data loader
                        }
                    }
                    
                    Section("Session Settings") {
                        InactivityTimeoutConfigView()
                    }
                }
            }
            .navigationTitle("Settings")
        }
        // END
    }
}

// ───── INACTIVITY TIMEOUT CONFIG VIEW ─────
struct InactivityTimeoutConfigView: View {
    @StateObject private var devSettings = DevSettingsManager.shared
    @State private var newTimeout: Double = 120.0
    @State private var showPinPrompt = false
    @State private var pinInput = ""
    @State private var showSuccessMessage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Auto Logout Timeout")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(devSettings.inactivityTimeout)) seconds")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(Int(newTimeout)) seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $newTimeout, in: 60...600, step: 30) {
                    Text("Timeout")
                }
                .accentColor(.blue)
            }
            
            HStack(spacing: 12) {
                Button("Update") {
                    showPinPrompt = true
                }
                .buttonStyle(.bordered)
                .disabled(newTimeout == devSettings.inactivityTimeout)
                
                if showSuccessMessage {
                    Text("Updated!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            newTimeout = devSettings.inactivityTimeout
        }
        .alert("SuperAdmin PIN Required", isPresented: $showPinPrompt) {
            SecureField("Enter SuperAdmin PIN", text: $pinInput)
            Button("Cancel", role: .cancel) {
                pinInput = ""
            }
            Button("Update") {
                updateTimeout()
            }
            .disabled(pinInput.isEmpty)
        } message: {
            Text("Enter your SuperAdmin PIN to change the inactivity timeout.")
        }
    }
    
    private func updateTimeout() {
        let success = devSettings.setInactivityTimeout(newTimeout, pin: pinInput)
        pinInput = ""
        
        if success {
            showSuccessMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSuccessMessage = false
            }
        } else {
            // PIN was incorrect - could show error message here
        }
    }
}

// ───── PREVIEW ─────
#Preview {
    let s = AppState.previewLoggedIn(role: .superadmin)
    SettingsView()
        .environmentObject(s)
}
// END
