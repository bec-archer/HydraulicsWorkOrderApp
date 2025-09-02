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
    
    /// Formats a phone number string to display format with dashes (local format only)
    /// Input: "+12345550001" -> Output: "234-555-0001"
    /// Input: "12345550001" -> Output: "234-555-0001"
    /// Input: "2345550001" -> Output: "234-555-0001"
    var formattedPhoneNumber: String {
        // Remove any existing formatting and country code
        let digitsOnly = self.filter { $0.isNumber }
        
        // For E164 numbers (11+ digits), strip country code and format as local
        if digitsOnly.count >= 11 {
            // Remove country code (first 1-3 digits) and format remaining as 10-digit local
            let localDigits = String(digitsOnly.suffix(10))
            if localDigits.count == 10 {
                let index1 = localDigits.index(localDigits.startIndex, offsetBy: 3)
                let index2 = localDigits.index(localDigits.startIndex, offsetBy: 6)
                return "\(localDigits[..<index1])-\(localDigits[index1..<index2])-\(localDigits[index2...])"
            }
        }
        
        // For 10-digit numbers, format as XXX-XXX-XXXX
        if digitsOnly.count == 10 {
            let index1 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 3)
            let index2 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 6)
            return "\(digitsOnly[..<index1])-\(digitsOnly[index1..<index2])-\(digitsOnly[index2...])"
        }
        
        // For 7-digit numbers, format as XXX-XXXX
        if digitsOnly.count == 7 {
            let index = digitsOnly.index(digitsOnly.startIndex, offsetBy: 3)
            return "\(digitsOnly[..<index])-\(digitsOnly[index...])"
        }
        
        // For other lengths, return as-is
        return digitsOnly
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

