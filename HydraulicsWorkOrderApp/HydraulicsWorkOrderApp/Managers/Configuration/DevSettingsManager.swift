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

final class DevSettingsManager: ObservableObject {
    static let shared = DevSettingsManager()

    // ───── UserDefaults Keys ─────
    private enum Keys {
        static let enableAnonAuth = "dev_enableAnonAuth"
    }

    // ───── Dev Toggles (Published) ─────
    @Published var skipLogin: Bool = true            // 🔐 Skip PIN login
    @Published var skipTagScan: Bool = true          // 🏷 Skip QR/RFID scan logic
    @Published var enableSampleData: Bool = false    // 🧪 Load sample WOs on launch

    // 🔐 NEW: Controls anonymous Firebase Auth at launch (persisted)
    @Published var enableAnonAuth: Bool = true {
        didSet {
            // Persist any change to UserDefaults so it survives app restarts
            UserDefaults.standard.set(enableAnonAuth, forKey: Keys.enableAnonAuth)
        }
    }

    // ───── Init ─────
    private init() {
        // Seed default ON if never set, then load current value
        if UserDefaults.standard.object(forKey: Keys.enableAnonAuth) == nil {
            UserDefaults.standard.set(true, forKey: Keys.enableAnonAuth)
        }
        self.enableAnonAuth = UserDefaults.standard.bool(forKey: Keys.enableAnonAuth)
    }
}
