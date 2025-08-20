import Foundation

// ─────────────────────────────────────────────────────────────
// 📄 WorkOrderNumberGenerator.swift
// Pure generator for creation-time WO numbers. Side-effect free.
// ─────────────────────────────────────────────────────────────

/// WorkOrder numbers are frozen at creation and NEVER recomputed later.
/// Format: "YYMMDD-###" e.g., "250820-001"
struct WorkOrderNumberGenerator {

    // ───── Public API (Creation-time only) ─────

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
}
// END
