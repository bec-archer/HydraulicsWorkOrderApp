//
//  CompletionDetailsSheet.swift
//  HydraulicsWorkOrderApp
//
//  Created by Assistant on 1/9/25.
//
//  Sheet that appears when a work order item status is updated to "Complete"
//  Collects required completion details: Parts Used, Hours, and Cost
//

import SwiftUI

struct CompletionDetailsSheet: View {
    let workOrder: WorkOrder
    let item: WO_Item
    let itemIndex: Int
    let onCompletionDetailsSaved: (String, String, String) -> Void
    let onCompletionCancelled: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @State private var partsUsed: String = ""
    @State private var hoursWorked: String = ""
    @State private var cost: String = ""
    @State private var isSaving = false
    
    // ───── VALIDATION ─────
    private var validationRequirements: CompletionValidationRequirements {
        CompletionRequirementsManager.shared.currentValidationRequirements
    }
    
    private var isFormValid: Bool {
        validationRequirements.isValid(
            parts: partsUsed,
            time: hoursWorked,
            cost: cost
        )
    }
    
    private var validationErrors: [String] {
        validationRequirements.getValidationErrors(
            parts: partsUsed,
            time: hoursWorked,
            cost: cost
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("Completion Details")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeManager.shared.textPrimary)
                    
                    Text("\(workOrder.workOrderNumber)-\(String(format: "%03d", itemIndex + 1))")
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                    
                    Text("Fields marked with * are required")
                        .font(.caption2)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                        .italic()
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Form Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Parts Used Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Parts Used")
                                    .font(.headline)
                                    .foregroundColor(ThemeManager.shared.textPrimary)
                                
                                if validationRequirements.partsRequired {
                                    Text("*")
                                        .foregroundColor(.red)
                                        .font(.headline)
                                } else {
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                }
                            }
                            
                            TextField("Enter parts used...", text: $partsUsed, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                                .background(ThemeManager.shared.cardBackground)
                                .cornerRadius(8)
                        }
                        
                        // Hours Worked Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Hours")
                                    .font(.headline)
                                    .foregroundColor(ThemeManager.shared.textPrimary)
                                
                                if validationRequirements.timeRequired {
                                    Text("*")
                                        .foregroundColor(.red)
                                        .font(.headline)
                                } else {
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                }
                            }
                            
                            TextField("Enter hours worked...", text: $hoursWorked)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .background(ThemeManager.shared.cardBackground)
                                .cornerRadius(8)
                        }
                        
                        // Cost Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Cost")
                                    .font(.headline)
                                    .foregroundColor(ThemeManager.shared.textPrimary)
                                
                                if validationRequirements.costRequired {
                                    Text("*")
                                        .foregroundColor(.red)
                                        .font(.headline)
                                } else {
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(ThemeManager.shared.textSecondary)
                                }
                            }
                            
                            TextField("Enter cost...", text: $cost)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .background(ThemeManager.shared.cardBackground)
                                .cornerRadius(8)
                        }
                        
                        // Validation Errors Section
                        if !validationErrors.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                    Text("Please complete required fields:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                }
                                
                                ForEach(validationErrors, id: \.self) { error in
                                    Text("• \(error)")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                        .padding(.leading, 16)
                                }
                            }
                            .padding(.top, 8)
                        }
                        
                        // Info Section
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(ThemeManager.shared.linkColor)
                                Text("Completion Information")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(ThemeManager.shared.textPrimary)
                            }
                            
                            Text("These details will be displayed at the bottom of the work order item card and used for cost tracking and reporting.")
                                .font(.caption2)
                                .foregroundColor(ThemeManager.shared.textSecondary)
                                .padding(.leading, 16)
                        }
                        .padding(.top, 4)
                        
                        Spacer(minLength: 8)
                        
                        // Big Yellow Save Button
                        Button(action: {
                            saveCompletionDetails()
                        }) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                }
                                
                                Text("Save Completion Details")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.yellow)
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            )
                        }
                        .disabled(!isFormValid || isSaving)
                        .opacity((!isFormValid || isSaving) ? 0.6 : 1.0)
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(ThemeManager.shared.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        print("🔍 DEBUG: Completion details sheet cancelled - status will remain unchanged")
                        onCompletionCancelled?()
                        dismiss()
                    }
                    .foregroundColor(ThemeManager.shared.textSecondary)
                }
                
                // Remove the trailing Save button since we have the big yellow one at bottom
            }
        }
        .onAppear {
            // Pre-populate with existing values if available
            partsUsed = item.partsUsed ?? ""
            hoursWorked = item.hoursWorked ?? ""
            cost = item.finalCost ?? ""
            
            print("🔍 DEBUG: CompletionDetailsSheet onAppear")
            print("🔍 DEBUG: Item ID: \(item.id)")
            print("🔍 DEBUG: Pre-populated values - Parts: '\(partsUsed)', Hours: '\(hoursWorked)', Cost: '\(cost)'")
            print("🔍 DEBUG: Original item values - Parts: '\(item.partsUsed ?? "nil")', Hours: '\(item.hoursWorked ?? "nil")', Cost: '\(item.finalCost ?? "nil")'")
        }
    }
    
    private func saveCompletionDetails() {
        guard isFormValid else { 
            print("🔍 DEBUG: Completion details form is not valid - cannot save")
            return 
        }
        
        print("🔍 DEBUG: Saving completion details - Parts: \(partsUsed), Hours: \(hoursWorked), Cost: \(cost)")
        isSaving = true
        
        // Clean up the input values
        let cleanedPartsUsed = partsUsed.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedHoursWorked = hoursWorked.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCost = cost.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 DEBUG: Calling onCompletionDetailsSaved callback")
        // Call the completion handler - this will change the status to Complete
        onCompletionDetailsSaved(cleanedPartsUsed, cleanedHoursWorked, cleanedCost)
        
        // Dismiss the sheet
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    CompletionDetailsSheet(
        workOrder: WorkOrder(
            id: "preview-wo",
            createdBy: "Tech",
            customerId: "preview-customer",
            customerName: "John Doe",
            customerCompany: "ABC Company",
            customerEmail: "john@abc.com",
            customerTaxExempt: false,
            customerPhone: "(555) 123-4567",
            workOrderType: "Intake",
            primaryImageURL: nil,
            timestamp: Date(),
            status: "Checked In",
            workOrderNumber: "250826-001",
            flagged: false,
            assetTagId: nil,
            estimatedCost: nil,
            finalCost: nil,
            dropdowns: [:],
            dropdownSchemaVersion: 1,
            lastModified: Date(),
            lastModifiedBy: "Tech",
            tagBypassReason: nil,
            isDeleted: false,
            syncStatus: "pending",
            lastSyncDate: nil,
            notes: [],
            items: []
        ),
        item: WO_Item.sample,
        itemIndex: 0,
        onCompletionDetailsSaved: { parts, hours, cost in
            print("Completion details saved: Parts=\(parts), Hours=\(hours), Cost=\(cost)")
        },
        onCompletionCancelled: {
            print("Completion details cancelled")
        }
    )
    .environmentObject(AppState.shared)
}
