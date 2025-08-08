
//
//  DropdownManager.swift
//  HydraulicsWorkOrderApp
//
//  Created by ChatGPT on behalf of Bec Archer
//

import SwiftUI

// ───── Singleton Manager for Dropdown Data ─────
class DropdownManager: ObservableObject {
    static let shared = DropdownManager()

    // Map of field keys to dropdown option arrays
    var options: [String: [DropdownOption]] = [:]

    private init() {
        loadDefaults()
    }

    private func loadDefaults() {
        options = [
            "type": [
                .init(label: "Cylinder", value: "Cylinder"),
                .init(label: "Pump", value: "Pump"),
                .init(label: "Hose", value: "Hose"),
                .init(label: "Valve", value: "Valve"),
                .init(label: "Other", value: "Other")
            ],
            "size": [
                .init(label: "Small", value: "Small"),
                .init(label: "Medium", value: "Medium"),
                .init(label: "Large", value: "Large"),
                .init(label: "Extra Large", value: "Extra Large"),
                .init(label: "Other", value: "Other")
            ],
            "color": [
                .init(label: "Black", value: "Black", colorHex: "#000000"),
                .init(label: "Silver", value: "Silver", colorHex: "#C0C0C0"),
                .init(label: "Yellow", value: "Yellow", colorHex: "#FFC500"),
                .init(label: "Blue", value: "Blue", colorHex: "#3B83BD"),
                .init(label: "Red", value: "Red", colorHex: "#FF0000"),
                .init(label: "Other", value: "Other")
            ],
            "machineType": [
                .init(label: "Forklift", value: "Forklift"),
                .init(label: "Skid Steer", value: "Skid Steer"),
                .init(label: "Excavator", value: "Excavator"),
                .init(label: "Tractor", value: "Tractor"),
                .init(label: "Other", value: "Other")
            ],
            "machineBrand": [
                .init(label: "Bobcat", value: "Bobcat"),
                .init(label: "Deere", value: "Deere"),
                .init(label: "Caterpillar", value: "Caterpillar"),
                .init(label: "Kubota", value: "Kubota"),
                .init(label: "Other", value: "Other")
            ],
            "reasonsForService": [
                .init(label: "Rebuild & Reseal", value: "Rebuild & Reseal"),
                .init(label: "Leaking", value: "Leaking"),
                .init(label: "Drifting", value: "Drifting"),
                .init(label: "Noise", value: "Noise"),
                .init(label: "Check Valves", value: "Check Valves"),
                .init(label: "Test", value: "Test"),
                .init(label: "Other", value: "Other")
            ]
        ]
    }
}
