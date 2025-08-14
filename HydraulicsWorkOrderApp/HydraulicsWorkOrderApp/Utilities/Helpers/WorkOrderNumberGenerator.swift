//  Utilities/Helpers/WorkOrderNumberGenerator.swift
//  HydraulicsWorkOrderApp
//
// ───── WORK ORDER NUMBER GENERATOR ─────
// Formats WO_Number as YYmmdd-### and helps compute the daily prefix.
// Uses UTC for consistency across devices.
// ───────────────────────────────────────

import Foundation

struct WorkOrderNumberGenerator {

    // ───── Daily Prefix (UTC) ─────
    static func dailyPrefix(for date: Date = Date()) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!  // UTC

        let fmt = DateFormatter()
        fmt.calendar = utc
        fmt.timeZone = utc.timeZone
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyMMdd"                    // YYmmdd
        return fmt.string(from: date)
    }
    // END

    // ───── Final Number Builder ─────
    static func build(prefix: String, sequence: Int) -> String {
        let clamped = max(sequence, 1)
        let seq = String(format: "%03d", clamped)
        return "\(prefix)-\(seq)"
    }
    // END

    // ───── Convenience ─────
    static func make(for date: Date = Date(), sequence: Int) -> String {
        let prefix = dailyPrefix(for: date)
        return build(prefix: prefix, sequence: sequence)
    }
    // END
}

// ───── PREVIEW TEMPLATE (UI-less) ─────
#if DEBUG
import SwiftUI

struct WorkOrderNumberGenerator_Preview: PreviewProvider {
    static var previews: some View {
        let prefix = WorkOrderNumberGenerator.dailyPrefix()
        let sample = WorkOrderNumberGenerator.build(prefix: prefix, sequence: 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Prefix (UTC today): \(prefix)")
            Text("Example WO_Number: \(sample)")
        }
        .padding()
        .previewDisplayName("WO Number Generator")
    }
}
#endif
// END
