//
//  CompletionRequirementsSettingsView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Assistant on 1/9/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 CompletionRequirementsSettingsView.swift
// Settings view for SuperAdmin/Admin to configure completion requirements
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct CompletionRequirementsSettingsView: View {
    // MARK: - Environment
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @StateObject private var requirementsManager = CompletionRequirementsManager.shared
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    // MARK: - Computed Properties
    private var canModifySettings: Bool {
        appState.isAdmin || appState.isSuperAdmin
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ───── Header Section ─────
                    headerSection
                    
                    // ───── Requirements Toggles ─────
                    requirementsSection
                    
                    // ───── Info Section ─────
                    infoSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(ThemeManager.shared.background)
            .navigationTitle("Completion Requirements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ThemeManager.shared.textSecondary)
                }
            }
        }
        .alert("Settings Updated", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text(successMessage)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Completion Requirements")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ThemeManager.shared.textPrimary)
            
            Text("Configure which fields are required when marking work order items as complete.")
                .font(.subheadline)
                .foregroundColor(ThemeManager.shared.textSecondary)
            
            if !canModifySettings {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                    Text("Admin or SuperAdmin access required")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(ThemeManager.shared.cardBackground)
        .cornerRadius(ThemeManager.shared.cardCornerRadius)
        .shadow(
            color: ThemeManager.shared.cardShadowColor.opacity(ThemeManager.shared.cardShadowOpacity),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Requirements Section
    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Required Fields")
                .font(.headline)
                .foregroundColor(ThemeManager.shared.textPrimary)
            
            // Parts Required Toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Parts Used")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ThemeManager.shared.textPrimary)
                        
                        Text("Require parts information when completing work order items")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $requirementsManager.partsRequired)
                        .disabled(!canModifySettings)
                        .onChange(of: requirementsManager.partsRequired) { _, newValue in
                            handleRequirementChange("Parts", newValue: newValue)
                        }
                }
                .padding()
                .background(ThemeManager.shared.cardBackground)
                .cornerRadius(8)
            }
            
            // Time Required Toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hours Worked")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ThemeManager.shared.textPrimary)
                        
                        Text("Require hours worked information when completing work order items")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $requirementsManager.timeRequired)
                        .disabled(!canModifySettings)
                        .onChange(of: requirementsManager.timeRequired) { _, newValue in
                            handleRequirementChange("Hours", newValue: newValue)
                        }
                }
                .padding()
                .background(ThemeManager.shared.cardBackground)
                .cornerRadius(8)
            }
            
            // Cost Required Toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cost")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ThemeManager.shared.textPrimary)
                        
                        Text("Require cost information when completing work order items")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $requirementsManager.costRequired)
                        .disabled(!canModifySettings)
                        .onChange(of: requirementsManager.costRequired) { _, newValue in
                            handleRequirementChange("Cost", newValue: newValue)
                        }
                }
                .padding()
                .background(ThemeManager.shared.cardBackground)
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(ThemeManager.shared.linkColor)
                Text("How it works")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeManager.shared.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• When a field is required, users must enter information before completing work order items")
                Text("• When a field is optional, users can leave it blank")
                Text("• These settings apply to all users in the system")
                Text("• Changes take effect immediately")
            }
            .font(.caption)
            .foregroundColor(ThemeManager.shared.textSecondary)
            .padding(.leading, 16)
        }
        .padding()
        .background(ThemeManager.shared.cardBackground)
        .cornerRadius(ThemeManager.shared.cardCornerRadius)
        .shadow(
            color: ThemeManager.shared.cardShadowColor.opacity(ThemeManager.shared.cardShadowOpacity),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Helper Methods
    private func handleRequirementChange(_ fieldName: String, newValue: Bool) {
        let status = newValue ? "required" : "optional"
        successMessage = "\(fieldName) field is now \(status)"
        showSuccessAlert = true
    }
}

// MARK: - Preview
#Preview {
    CompletionRequirementsSettingsView()
        .environmentObject(AppState.previewLoggedIn(role: .admin))
}
