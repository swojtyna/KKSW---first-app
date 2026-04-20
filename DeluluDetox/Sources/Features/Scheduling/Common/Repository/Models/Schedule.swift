import Foundation

/// Persisted schedule record (CONTEXT §D-01, D-02). Stored in `schedule.json`
/// as an array of `Schedule` (schema supports N; MVP surfaces first).
/// `daysOfWeek` uses Calendar.weekday values (1=Sunday..7=Saturday) —
/// UI layer maps display order (Pn..Nd) to these values, never vice versa.
struct Schedule: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String?
    var daysOfWeek: [Int]          // Calendar.weekday (1=Sun..7=Sat)
    var startHour: Int             // 0..23
    var startMinute: Int           // 0..59
    var endHour: Int               // 0..23
    var endMinute: Int             // 0..59
    var enabled: Bool
    var blocklistId: UUID
    var appVersion: String

    /// True iff `(endHour, endMinute) <= (startHour, startMinute)` — schedule wraps past midnight (D-03).
    var crossesMidnight: Bool {
        let startMin = startHour * 60 + startMinute
        let endMin = endHour * 60 + endMinute
        return endMin <= startMin
    }
}
