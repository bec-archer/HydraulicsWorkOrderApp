//
//  CompletionRequirementsManager.swift
//  HydraulicsWorkOrderApp
//
//  Created by Assistant on 1/9/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 CompletionRequirementsManager.swift
// Manages completion requirements configuration for SuperAdmin/Admin
// ─────────────────────────────────────────────────────────────

import Foundation
import Combine

// Keep UI updates on the main actor
@MainActor
final class CompletionRequirementsManager: ObservableObject {
    
    // Singleton
    static let shared = CompletionRequirementsManager()
    
    // ───── UserDefaults Keys ─────
    private enum Keys {
        static let partsRequired = "completion_partsRequired"
        static let timeRequired = "completion_timeRequired"
        static let costRequired = "completion_costRequired"
    }
    
    // ───── Completion Requirements (Published) ─────
    
    // Whether parts are required for completion (default: true)
    @Published var partsRequired: Bool = UserDefaults.standard.object(forKey: Keys.partsRequired) as? Bool ?? true {
        didSet { UserDefaults.standard.set(partsRequired, forKey: Keys.partsRequired) }
    }
    
    // Whether time is required for completion (default: true)
    @Published var timeRequired: Bool = UserDefaults.standard.object(forKey: Keys.timeRequired) as? Bool ?? true {
        didSet { UserDefaults.standard.set(timeRequired, forKey: Keys.timeRequired) }
    }
    
    // Whether cost is required for completion (default: true)
    @Published var costRequired: Bool = UserDefaults.standard.object(forKey: Keys.costRequired) as? Bool ?? true {
        didSet { UserDefaults.standard.set(costRequired, forKey: Keys.costRequired) }
    }
    
    // ───── Computed Properties ─────
    
    /// Check if current user can modify completion requirements
    var canModifyRequirements: Bool {
        let appState = AppState.shared
        return appState.isAdmin || appState.isSuperAdmin
    }
    
    /// Get validation requirements for the current user role
    var currentValidationRequirements: CompletionValidationRequirements {
        return CompletionValidationRequirements(
            partsRequired: partsRequired,
            timeRequired: timeRequired,
            costRequired: costRequired
        )
    }
    
    // ───── SuperAdmin/Admin-Gated Setters ─────
    
    @discardableResult
    func setPartsRequired(_ newValue: Bool) -> Bool {
        guard canModifyRequirements else { return false }
        partsRequired = newValue
        return true
    }
    
    @discardableResult
    func setTimeRequired(_ newValue: Bool) -> Bool {
        guard canModifyRequirements else { return false }
        timeRequired = newValue
        return true
    }
    
    @discardableResult
    func setCostRequired(_ newValue: Bool) -> Bool {
        guard canModifyRequirements else { return false }
        costRequired = newValue
        return true
    }
    
    // ───── Init ─────
    private init() {
        // Seed defaults on first run
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.partsRequired) == nil { defaults.set(true, forKey: Keys.partsRequired) }
        if defaults.object(forKey: Keys.timeRequired) == nil { defaults.set(true, forKey: Keys.timeRequired) }
        if defaults.object(forKey: Keys.costRequired) == nil { defaults.set(true, forKey: Keys.costRequired) }
        
        // Ensure published values reflect stored defaults on launch
        self.partsRequired = defaults.bool(forKey: Keys.partsRequired)
        self.timeRequired = defaults.bool(forKey: Keys.timeRequired)
        self.costRequired = defaults.bool(forKey: Keys.costRequired)
    }
}

// END
