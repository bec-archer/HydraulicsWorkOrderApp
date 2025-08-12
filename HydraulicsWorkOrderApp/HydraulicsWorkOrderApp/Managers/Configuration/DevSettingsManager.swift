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

    // ───── Dev Toggles (Published) ─────
    @Published var skipLogin: Bool = true           // 🔐 Skip PIN login
    @Published var skipTagScan: Bool = true        // 🏷 Skip QR/RFID scan logic
    @Published var enableSampleData: Bool = false   // 🧪 Load sample WOs on launch

    private init() {}
}
