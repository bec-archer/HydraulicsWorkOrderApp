//
//  String+PhoneFormatting.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import Foundation

// ─────────────────────────────────────────────────────────────
// 📄 String+PhoneFormatting.swift
// Extension to format phone numbers with dashes for display
// ─────────────────────────────────────────────────────────────

extension String {
    
    /// Formats a phone number string to display format with dashes
    /// Input: "2392467352" -> Output: "239-246-7352"
    /// Input: "239246735" -> Output: "239-246-735"
    /// Input: "23924673" -> Output: "239-246-73"
    var formattedPhoneNumber: String {
        // Remove any existing formatting
        let digitsOnly = self.filter { $0.isNumber }
        
        // Format based on length
        switch digitsOnly.count {
        case 10: // Standard US phone number: 239-246-7352
            let index1 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 3)
            let index2 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 6)
            return "\(digitsOnly[..<index1])-\(digitsOnly[index1..<index2])-\(digitsOnly[index2...])"
            
        case 7: // 7-digit number: 239-2467
            let index = digitsOnly.index(digitsOnly.startIndex, offsetBy: 3)
            return "\(digitsOnly[..<index])-\(digitsOnly[index...])"
            
        case 11: // 11-digit with country code: 1-239-246-7352
            if digitsOnly.hasPrefix("1") {
                let index1 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 1)
                let index2 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 4)
                let index3 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 7)
                return "\(digitsOnly[..<index1])-\(digitsOnly[index1..<index2])-\(digitsOnly[index2..<index3])-\(digitsOnly[index3...])"
            } else {
                // Fall back to 10-digit formatting
                let index1 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 3)
                let index2 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 6)
                return "\(digitsOnly[..<index1])-\(digitsOnly[index1..<index2])-\(digitsOnly[index2...])"
            }
            
        default:
            // For other lengths, just return the original or add dashes every 3-4 digits
            if digitsOnly.count > 4 {
                var formatted = ""
                var remaining = digitsOnly
                
                while remaining.count > 4 {
                    let chunkSize = min(3, remaining.count - 1)
                    let index = remaining.index(remaining.startIndex, offsetBy: chunkSize)
                    formatted += remaining[..<index] + "-"
                    remaining = String(remaining[index...])
                }
                formatted += remaining
                return formatted
            } else {
                return digitsOnly
            }
        }
    }
    
    /// Returns only the digits from a phone number string
    var digitsOnly: String {
        return self.filter { $0.isNumber }
    }
    
    /// Checks if the string is a valid phone number format
    var isValidPhoneNumber: Bool {
        let digitsOnly = self.digitsOnly
        return digitsOnly.count >= 7 && digitsOnly.count <= 15
    }
}
