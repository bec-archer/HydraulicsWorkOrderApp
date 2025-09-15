//
//  DevSettingsManager.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 DevSettingsManager.swift
// Developer-only toggles for testing and bypassing logic
// ─────────────────────────────────────────────────────────────

import Foundation
import Combine

// Keep UI updates on the main actor
@MainActor
final class DevSettingsManager: ObservableObject {

    // Singleton
    static let shared = DevSettingsManager()

    // ───── UserDefaults Keys ─────
    private enum Keys {
        static let enableAnonAuth = "dev_enableAnonAuth"
        static let bypassLogin    = "dev_bypassLogin"
        static let enforceTagScan = "dev_enforceTagScan"
        static let inactivityTimeout = "dev_inactivityTimeout"
    }

    // ───── Dev Toggles (Published) ─────

    // Skip PIN/login entirely → boot straight to ActiveWorkOrdersView
    @Published var skipLogin: Bool = UserDefaults.standard.object(forKey: Keys.bypassLogin) as? Bool ?? false {
        didSet { UserDefaults.standard.set(skipLogin, forKey: Keys.bypassLogin) }
    }

    // Alias to match “bypass login” wording used elsewhere
    var bypassLogin: Bool {
        get { skipLogin }
        set { skipLogin = newValue }
    }

    // Toggle tag-scan enforcement (false = enforce tag scan, true = bypass tag scan)
    @Published var skipTagScan: Bool = UserDefaults.standard.object(forKey: Keys.enforceTagScan) as? Bool ?? false {
        didSet { UserDefaults.standard.set(skipTagScan, forKey: Keys.enforceTagScan) }
    }


    // Controls anonymous Firebase Auth at launch (persisted)
    @Published var enableAnonAuth: Bool = UserDefaults.standard.object(forKey: Keys.enableAnonAuth) as? Bool ?? true {
        didSet { UserDefaults.standard.set(enableAnonAuth, forKey: Keys.enableAnonAuth) }
    }
    
    // Inactivity timeout in seconds (Admin/SuperAdmin configurable)
    @Published var inactivityTimeout: TimeInterval = UserDefaults.standard.object(forKey: Keys.inactivityTimeout) as? TimeInterval ?? 120.0 {
        didSet { UserDefaults.standard.set(inactivityTimeout, forKey: Keys.inactivityTimeout) }
    }

    // ───── SuperAdmin-Gated Setter ─────
    // ───── SuperAdmin-Gated Setter (uses AppState verifier) ─────
    @discardableResult
    func setBypassLogin(_ newValue: Bool, pin: String) -> Bool {
        guard AppState.shared.verifySuperAdmin(pin: pin) else { return false }
        skipLogin = newValue
        return true
    }
    
    @discardableResult
    func setInactivityTimeout(_ newValue: TimeInterval, pin: String) -> Bool {
        guard AppState.shared.verifySuperAdmin(pin: pin) else { return false }
        inactivityTimeout = newValue
        return true
    }

    // ───── Init ─────
    private init() {
        // Seed defaults on first run
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.enableAnonAuth) == nil { defaults.set(true,  forKey: Keys.enableAnonAuth) }
        if defaults.object(forKey: Keys.bypassLogin)    == nil { defaults.set(false, forKey: Keys.bypassLogin) }
        if defaults.object(forKey: Keys.enforceTagScan) == nil { defaults.set(false, forKey: Keys.enforceTagScan) }
        if defaults.object(forKey: Keys.inactivityTimeout) == nil { defaults.set(120.0, forKey: Keys.inactivityTimeout) }

        // Ensure published values reflect stored defaults on launch
        self.enableAnonAuth   = defaults.bool(forKey: Keys.enableAnonAuth)
        self.skipLogin        = defaults.bool(forKey: Keys.bypassLogin)
        self.skipTagScan      = defaults.bool(forKey: Keys.enforceTagScan)
        self.inactivityTimeout = defaults.double(forKey: Keys.inactivityTimeout)

        // ───── Debug Override: always bypass login in DEBUG builds ─────
        #if DEBUG
        // Comment out to enable login screen in debug builds
        // self.skipLogin = true   // will persist via didSet
        #endif
        // END Debug Override
    }
}
// END
