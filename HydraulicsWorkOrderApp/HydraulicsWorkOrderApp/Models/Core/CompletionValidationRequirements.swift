//
//  CompletionValidationRequirements.swift
//  HydraulicsWorkOrderApp
//
//  Created by Assistant on 1/9/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 CompletionValidationRequirements.swift
// Validation requirements for work order completion
// ─────────────────────────────────────────────────────────────

import Foundation

// ───── VALIDATION REQUIREMENTS STRUCT ─────
struct CompletionValidationRequirements {
    let partsRequired: Bool
    let timeRequired: Bool
    let costRequired: Bool
    
    /// Check if a completion form is valid based on these requirements
    func isValid(parts: String, time: String, cost: String) -> Bool {
        let partsValid = !partsRequired || !parts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let timeValid = !timeRequired || !time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let costValid = !costRequired || !cost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        return partsValid && timeValid && costValid
    }
    
    /// Get validation errors for display
    func getValidationErrors(parts: String, time: String, cost: String) -> [String] {
        var errors: [String] = []
        
        if partsRequired && parts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Parts Used is required")
        }
        
        if timeRequired && time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Hours Worked is required")
        }
        
        if costRequired && cost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Cost is required")
        }
        
        return errors
    }
}
// END
