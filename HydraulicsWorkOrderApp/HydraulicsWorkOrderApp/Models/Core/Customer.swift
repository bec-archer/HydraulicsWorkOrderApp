//
//  Customer.swift
//  HydraulicsWorkOrderApp
//
//  Core Customer model – Core Data first, with consistent naming.
//
import Foundation

struct Customer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var phoneNumber: String  // Renamed from phone for consistency
    var company: String?
    var email: String?
    var taxExempt: Bool
    var emojiTag: String?  // Optional emoji tag for customer identification
    var lastModified: Date
    var lastSyncDate: Date?
    var syncStatus: CustomerSyncStatus
    
    // MARK: - Initializers
    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String,
        company: String? = nil,
        email: String? = nil,
        taxExempt: Bool = false,
        emojiTag: String? = nil,
        lastModified: Date = Date(),
        lastSyncDate: Date? = nil,
        syncStatus: CustomerSyncStatus = .pending
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.company = company
        self.email = email
        self.taxExempt = taxExempt
        self.emojiTag = emojiTag
        self.lastModified = lastModified
        self.lastSyncDate = lastSyncDate
        self.syncStatus = syncStatus
    }
    
    // MARK: - Convenience Initializer
    init() {
        self.id = UUID()
        self.name = ""
        self.phoneNumber = ""
        self.company = nil
        self.email = nil
        self.taxExempt = false
        self.emojiTag = nil
        self.lastModified = Date()
        self.lastSyncDate = nil
        self.syncStatus = .pending
    }
    
    static var sample: Customer {
        Customer(
            id: UUID(),
            name: "Sample Customer",
            phoneNumber: "555-123-4567",
            company: "Sample Company",
            email: "sample@example.com",
            taxExempt: false,
            emojiTag: "🔧"
        )
    }
}

// MARK: - Sync Status
enum CustomerSyncStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .failed: return "Failed"
        }
    }
    
    var isSynced: Bool {
        self == .synced
    }
    
    var needsSync: Bool {
        self == .pending || self == .failed
    }
}

// MARK: - Extensions
extension Customer {
    
    // MARK: - Validation
    var isValid: Bool {
        !name.isEmpty && !phoneNumber.isEmpty
    }
    
    var displayName: String {
        let baseName = if let company = company, !company.isEmpty {
            "\(name) (\(company))"
        } else {
            name
        }
        
        if let emoji = emojiTag, !emoji.isEmpty {
            return "\(emoji) \(baseName)"
        }
        return baseName
    }
    
    var formattedPhone: String {
        // Basic phone formatting
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if cleaned.count == 10 {
            let index = cleaned.index(cleaned.startIndex, offsetBy: 3)
            let index2 = cleaned.index(cleaned.startIndex, offsetBy: 6)
            return "(\(cleaned[..<index])) \(cleaned[index..<index2])-\(cleaned[index2...])"
        }
        return phoneNumber
    }
    
    var needsSync: Bool {
        syncStatus.needsSync
    }
    
    // MARK: - Emoji Management
    
    /// Validate and set emoji tag (keeps only first grapheme)
    mutating func setEmojiTag(_ emoji: String?) {
        if let emoji = emoji, !emoji.isEmpty {
            // Keep only the first grapheme (visible character)
            let firstGrapheme = String(emoji.prefix(1))
            self.emojiTag = firstGrapheme
        } else {
            self.emojiTag = nil
        }
    }
    
    /// Validate emoji input (must be single emoji)
    static func isValidEmoji(_ emoji: String) -> Bool {
        guard !emoji.isEmpty else { return true } // Empty is valid (no emoji)
        
        // Check if it's a single grapheme (visible character)
        let graphemes = emoji.unicodeScalars.compactMap { scalar in
            Character(scalar)
        }
        
        return graphemes.count == 1
    }
}

// MARK: - Equatable
extension Customer {
    static func == (lhs: Customer, rhs: Customer) -> Bool {
        lhs.id == rhs.id && lhs.lastModified == rhs.lastModified
    }
}

// MARK: - Hashable
extension Customer: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
