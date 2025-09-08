
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
    @Published var options: [String: [DropdownOption]] = [:]
    
    // Schema version management
    @MainActor
    private let versionService = DropdownVersionService.shared

    private init() {
        loadDefaults()
    }

    // ───── Load defaults from template (admin can reorder/modify later) ─────
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
                .init(label: "< 24\"", value: "< 24\""),
                .init(label: "24\" - 36\"", value: "24\" - 36\""),
                .init(label: "> 36\"", value: "> 36\"")
            ],
            "color": [
                .init(label: "Black",  value: "Black",  colorHex: "#000000"),
                .init(label: "Red",    value: "Red",    colorHex: "#FF0000"),
                .init(label: "Yellow", value: "Yellow", colorHex: "#FFC500"),
                .init(label: "White",  value: "White",  colorHex: "#FFFFFF"),
                .init(label: "Gray",   value: "Gray",   colorHex: "#808080"),
                .init(label: "Orange", value: "Orange", colorHex: "#F7941D"),
                .init(label: "Other",  value: "Other") // opens ColorPicker
            ],
            "machineType": [
                .init(label: "Forklift",   value: "Forklift"),
                .init(label: "Skid Steer", value: "Skid Steer"),
                .init(label: "Excavator",  value: "Excavator"),
                .init(label: "Tractor",    value: "Tractor"),
                .init(label: "Truck",      value: "Truck"),
                .init(label: "Trailer",    value: "Trailer"),
                .init(label: "Other",      value: "Other")
            ],
            "machineBrand": [
                .init(label: "Bobcat",      value: "Bobcat"),
                .init(label: "Case",        value: "Case"),
                .init(label: "Caterpillar", value: "Caterpillar"),
                .init(label: "Doosan",      value: "Doosan"),
                .init(label: "Hyundai",     value: "Hyundai"),
                .init(label: "JCB",         value: "JCB"),
                .init(label: "John Deere",  value: "John Deere"),
                .init(label: "Komatsu",     value: "Komatsu"),
                .init(label: "Kubota",      value: "Kubota"),
                .init(label: "New Holland", value: "New Holland"),
                .init(label: "Takeuchi",    value: "Takeuchi"),
                .init(label: "Terex",       value: "Terex"),
                .init(label: "Vermeer",     value: "Vermeer"),
                .init(label: "Other",       value: "Other")
            ],
            "waitTime": [
                .init(label: "8 hrs",  value: "8 hrs"),
                .init(label: "24 hrs", value: "24 hrs"),
                .init(label: "48 hrs", value: "48 hrs"),
                .init(label: "72 hrs", value: "72 hrs"),
                .init(label: "7 days", value: "7 days"),
                .init(label: "TBD",    value: "TBD")
            ],
            "reasonsForService": [
                .init(label: "Replace Seals",       value: "Replace Seals"),
                .init(label: "Rod Damage",          value: "Rod Damage"),
                .init(label: "Barrel Damage",       value: "Barrel Damage"),
                .init(label: "Check Valves",        value: "Check Valves"),
                .init(label: "Thread Damage",       value: "Thread Damage"),
                .init(label: "Bushings",            value: "Bushings"),
                .init(label: "Bent Rod",            value: "Bent Rod"),
                .init(label: "Fittings - Repair",   value: "Fittings - Repair"),
                .init(label: "Fittings - Replace",  value: "Fittings - Replace"),
                .init(label: "Hard Lines - Repair", value: "Hard Lines - Repair"),
                .init(label: "Hard Lines - Replace",value: "Hard Lines - Replace"),
                .init(label: "Other", value: "Other")
            ]
        ]
    }
}
