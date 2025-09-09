import Foundation
import UIKit

class ValidationService {
    // MARK: - Singleton
    static let shared = ValidationService()
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Work Order Validation
    
    /// Validate a complete work order
    @MainActor
    func validateWorkOrder(_ workOrder: WorkOrder) -> ValidationResult {
        var errors: [String] = []
        
        // Validate customer (reconstruct Customer object from WorkOrder properties)
        let customer = Customer(
            id: UUID(uuidString: workOrder.customerId) ?? UUID(),
            name: workOrder.customerName,
            phoneNumber: workOrder.customerPhone,
            company: workOrder.customerCompany,
            email: workOrder.customerEmail,
            taxExempt: workOrder.customerTaxExempt,
            emojiTag: workOrder.customerEmojiTag
        )
        let customerValidation = validateCustomer(customer)
        errors.append(contentsOf: customerValidation.errors)
        
        // Validate items
        let itemsValidation = validateItems(workOrder.items)
        errors.append(contentsOf: itemsValidation.errors)
        
        // Validate work order number
        if workOrder.workOrderNumber.isEmpty {
            errors.append("Work order number is required")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    /// Validate customer information
    func validateCustomer(_ customer: Customer) -> ValidationResult {
        var errors: [String] = []
        
        if customer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Customer name is required")
        }
        
        if customer.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Customer phone number is required")
        }
        
        // Validate phone number format (basic validation)
        if !isValidPhoneNumber(customer.phoneNumber) {
            errors.append("Invalid phone number format")
        }
        
        // Validate email if provided
        if let email = customer.email, !email.isEmpty {
            if !isValidEmail(email) {
                errors.append("Invalid email format")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    /// Validate work order items
    @MainActor
    func validateItems(_ items: [WO_Item]) -> ValidationResult {
        var errors: [String] = []
        
        if items.isEmpty {
            errors.append("At least one item is required")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        for (index, item) in items.enumerated() {
            let itemValidation = validateItem(item, at: index)
            errors.append(contentsOf: itemValidation.errors)
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    /// Validate a single work order item
    @MainActor
    func validateItem(_ item: WO_Item, at index: Int? = nil) -> ValidationResult {
        var errors: [String] = []
        let itemPrefix = index != nil ? "Item \(index! + 1): " : ""
        
        // Validate type
        if item.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("\(itemPrefix)Type is required")
        }
        
        // Validate images
        if item.imageUrls.isEmpty {
            errors.append("\(itemPrefix)At least one image is required")
        }
        
        // Validate reasons for service
        if item.reasonsForService.isEmpty {
            errors.append("\(itemPrefix)At least one reason for service is required")
        }
        
        // Validate tag ID - check if tag scan enforcement is enabled
        let isTagScanEnforced = !DevSettingsManager.shared.skipTagScan
        
        if isTagScanEnforced {
            // Tag scan enforcement is enabled - asset tag is required
            if let tagId = item.assetTagId, !tagId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !isValidTagId(tagId) {
                    errors.append("\(itemPrefix)Invalid tag ID format")
                }
            } else {
                errors.append("\(itemPrefix)Asset tag ID is required")
            }
        } else {
            // Tag scan enforcement is bypassed - only validate format if provided
            if let tagId = item.assetTagId, !tagId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !isValidTagId(tagId) {
                    errors.append("\(itemPrefix)Invalid tag ID format")
                }
            }
        }
        
        // Validate dropdowns
        let dropdownValidation = validateDropdowns(item.dropdowns)
        errors.append(contentsOf: dropdownValidation.errors.map { "\(itemPrefix)\($0)" })
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    /// Validate dropdown selections
    func validateDropdowns(_ dropdowns: [String: String]) -> ValidationResult {
        var errors: [String] = []
        
        // Check for required dropdowns
        let requiredDropdowns = ["type", "color", "size"] // Add more as needed
        
        for requiredDropdown in requiredDropdowns {
            if let value = dropdowns[requiredDropdown], value.isEmpty {
                errors.append("\(requiredDropdown.capitalized) selection is required")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Form Validation
    
    /// Validate new work order form
    @MainActor
    func validateNewWorkOrderForm(customer: Customer?, items: [WO_Item]) -> ValidationResult {
        var errors: [String] = []
        
        // Validate customer
        if let customer = customer {
            let customerValidation = validateCustomer(customer)
            errors.append(contentsOf: customerValidation.errors)
        } else {
            errors.append("Customer selection is required")
        }
        
        // Validate items
        let itemsValidation = validateItems(items)
        errors.append(contentsOf: itemsValidation.errors)
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    /// Check if work order can be checked in
    @MainActor
    func canCheckInWorkOrder(customer: Customer?, items: [WO_Item]) -> Bool {
        let validation = validateNewWorkOrderForm(customer: customer, items: items)
        return validation.isValid
    }
    
    // MARK: - Status Validation
    
    /// Validate status transition
    func validateStatusTransition(from currentStatus: String, to newStatus: String) -> ValidationResult {
        var errors: [String] = []
        
        // Define valid status transitions
        let validTransitions: [String: [String]] = [
            "Checked In": ["Disassembly", "In Progress", "Closed"],
            "Disassembly": ["In Progress", "Test Failed", "Closed"],
            "In Progress": ["Test Failed", "Complete", "Closed"],
            "Test Failed": ["In Progress", "Complete", "Closed"],
            "Complete": ["Closed"],
            "Closed": [] // No further transitions from closed
        ]
        
        guard let allowedTransitions = validTransitions[currentStatus] else {
            errors.append("Invalid current status")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        if !allowedTransitions.contains(newStatus) {
            errors.append("Cannot transition from \(currentStatus) to \(newStatus)")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Utility Validation Methods
    
    /// Validate phone number format
    private func isValidPhoneNumber(_ phone: String) -> Bool {
        let phoneRegex = #"^[\+]?[1-9][\d]{0,15}$"#
        return phone.range(of: phoneRegex, options: .regularExpression) != nil
    }
    
    /// Validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return email.range(of: emailRegex, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    /// Validate tag ID format
    private func isValidTagId(_ tagId: String) -> Bool {
        // Add specific tag ID validation rules as needed
        return !tagId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Validation Result
struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    
    var errorMessage: String? {
        guard !errors.isEmpty else { return nil }
        return errors.joined(separator: "\n")
    }
}

// MARK: - Validation Extensions
extension ValidationService {
    /// Validate note content
    func validateNote(_ noteText: String) -> ValidationResult {
        var errors: [String] = []
        
        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedText.isEmpty {
            errors.append("Note text cannot be empty")
        }
        
        if trimmedText.count > 1000 {
            errors.append("Note text cannot exceed 1000 characters")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    /// Validate image upload
    func validateImageUpload(_ images: [UIImage]) -> ValidationResult {
        var errors: [String] = []
        
        if images.isEmpty {
            errors.append("At least one image is required")
        }
        
        for (index, image) in images.enumerated() {
            if image.size.width < 100 || image.size.height < 100 {
                errors.append("Image \(index + 1) is too small (minimum 100x100 pixels)")
            }
            
            // Check file size (rough estimate)
            if let imageData = image.jpegData(compressionQuality: 1.0) {
                let sizeInMB = Double(imageData.count) / 1024.0 / 1024.0
                if sizeInMB > 10 {
                    errors.append("Image \(index + 1) is too large (maximum 10MB)")
                }
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
}
