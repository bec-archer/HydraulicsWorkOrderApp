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

// MARK: - DevSettingsManager

final class DevSettingsManager {
    static let shared = DevSettingsManager()

    // ───── Dev Toggles ─────
    var skipLogin: Bool = true            // 🔐 Skip PIN login
    var bypassTagScan: Bool = false       // 🏷 Skip QR/RFID scan logic
    var enableSampleData: Bool = false    // 🧪 Load sample WOs on launch

    private init() {}
}
