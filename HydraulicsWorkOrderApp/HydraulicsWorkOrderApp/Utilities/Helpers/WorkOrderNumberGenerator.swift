import Foundation

// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderNumberGenerator.swift
// Pure generator for creation-time WO numbers. Side-effect free.
// ─────────────────────────────────────────────────────────────

/*
    WARNING: This WorkOrderNumberGenerator is a critical component of the project.
    It is core functionality that must remain unchanged and unaltered.
    Any modifications to this generator could compromise the stability and data integrity of the system.
    DO NOT change or refactor this code without explicit authorization and thorough testing.
*/

/// WorkOrder numbers are frozen at creation and NEVER recomputed later.
/// Format: "YYMMDD-###" e.g., "250820-001"
struct WorkOrderNumberGenerator {

    // ───── Public API (Creation-time only) ─────

    /// Generates a work order number for today's date (synchronous version for initialization).
    static func generateWorkOrderNumber() -> String {
        print("🚨🚨🚨 WORK ORDER NUMBER GENERATOR CALLED! 🚨🚨🚨")
        let today = Date()
        let nextSequence = 1 // Default to 1 for initialization, will be updated later if needed
        let result = make(date: today, sequence: nextSequence)
        print("🚨🚨🚨 Generated work order number: \(result) 🚨🚨🚨")
        return result
    }
    
    /// Generates the next available work order number for today's date (async version for database checking).
    static func generateWorkOrderNumberAsync() async -> String {
        print("🚨🚨🚨 WORK ORDER NUMBER GENERATOR CALLED! 🚨🚨🚨")
        let today = Date()
        let nextSequence = await getNextSequenceForDate(today)
        let result = make(date: today, sequence: nextSequence)
        print("🚨🚨🚨 Generated work order number: \(result) 🚨🚨🚨")
        return result
    }

    /// Formats a work order number using a specific date and a 1-based sequence.
    /// - Parameters:
    ///   - date: The creation date to freeze into the WO number.
    ///   - sequence: 1-based sequence for that date (e.g., 1 -> "001").
    /// - Returns: e.g. "250820-001"
    static func make(date: Date, sequence: Int) -> String {
        let prefix = Self.prefix(from: date)
        let seq = String(format: "%03d", max(1, sequence))
        return "\(prefix)-\(seq)"
    }

    /// Convenience used by existing call sites that already computed the sequence but
    /// want "today" as the date. Safe for *creation-time fallback only*.
    /// - Parameter sequence: 1-based sequence.
    static func make(sequence: Int) -> String {
        return make(date: Date(), sequence: sequence)
    }

    // ───── Internals ─────

    /// Builds the "YYMMDD" prefix for a given date in UTC to keep numbers stable across devices.
    private static func prefix(from date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let yy = (comps.year ?? 2000) % 100
        let mm = comps.month ?? 1
        let dd = comps.day ?? 1
        return String(format: "%02d%02d%02d", yy, mm, dd)
    }

    /// Gets the next available sequence number for a given date by querying existing work orders.
    private static func getNextSequenceForDate(_ date: Date) async -> Int {
        let todayPrefix = prefix(from: date)
        print("🔍 DEBUG: Generating work order number for date: \(todayPrefix)")
        
        let workOrders = await MainActor.run {
            WorkOrdersDatabase.shared.workOrders
        }
        print("🔍 DEBUG: Total work orders in database: \(workOrders.count)")
        
        let todaysWorkOrders = workOrders.filter { workOrder in
            workOrder.workOrderNumber.hasPrefix(todayPrefix)
        }
        print("🔍 DEBUG: Work orders for today (\(todayPrefix)): \(todaysWorkOrders.count)")
        
        for wo in todaysWorkOrders {
            print("🔍 DEBUG: Found today's WO: \(wo.workOrderNumber)")
        }
        
        let sequences = todaysWorkOrders.compactMap { workOrder -> Int? in
            let components = workOrder.workOrderNumber.components(separatedBy: "-")
            print("🔍 DEBUG: Parsing WO \(workOrder.workOrderNumber) - components: \(components)")
            
            guard components.count == 2,
                  let sequenceStr = components.last,
                  let sequence = Int(sequenceStr) else {
                print("🔍 DEBUG: Failed to parse sequence from \(workOrder.workOrderNumber)")
                return nil
            }
            print("🔍 DEBUG: Successfully parsed sequence: \(sequence)")
            return sequence
        }
        
        print("🔍 DEBUG: Extracted sequences: \(sequences)")
        
        let maxSequence = sequences.max() ?? 0
        let nextSequence = maxSequence + 1
        print("🔍 DEBUG: Max sequence: \(maxSequence), Next sequence: \(nextSequence)")
        
        return nextSequence
    }
}
// END
