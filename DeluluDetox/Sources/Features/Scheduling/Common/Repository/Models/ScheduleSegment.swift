import Foundation

/// Cross-midnight split marker (CONTEXT §D-03, D-13). Single-day schedules
/// use `.main`; cross-midnight schedules register TWO DAS — `.evening`
/// (intervalStart → 23:59:59) and `.morning` (00:00:00 → intervalEnd).
enum ScheduleSegment: String, Codable, Equatable, Sendable {
    case main
    case evening
    case morning
}
