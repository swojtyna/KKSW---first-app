import Foundation
@testable import DeluluDetox

/// Deterministic builders for ComputeStatsUseCase test scenarios.
enum SessionRecordFixtures {
    static let fixedBlocklistId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    /// Completed session whose `actualEndAt` is `day` at noon local time.
    static func completed(on day: Date, calendar: Calendar = .current, id: UUID = UUID()) -> SessionRecord {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        return SessionRecord(
            id: id,
            blocklistId: fixedBlocklistId,
            startedAt: noon.addingTimeInterval(-1800),
            plannedEndAt: noon,
            plannedDurationSeconds: 1800,
            actualEndAt: noon,
            outcome: .completed,
            appVersion: "test"
        )
    }

    static func cancelled(on day: Date, calendar: Calendar = .current) -> SessionRecord {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        return SessionRecord(
            id: UUID(),
            blocklistId: fixedBlocklistId,
            startedAt: noon.addingTimeInterval(-1800),
            plannedEndAt: noon,
            plannedDurationSeconds: 1800,
            actualEndAt: noon,
            outcome: .cancelledByUser,
            appVersion: "test"
        )
    }

    static func brokenByRevoke(on day: Date, calendar: Calendar = .current) -> SessionRecord {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        return SessionRecord(
            id: UUID(),
            blocklistId: fixedBlocklistId,
            startedAt: noon.addingTimeInterval(-1800),
            plannedEndAt: noon,
            plannedDurationSeconds: 1800,
            actualEndAt: noon,
            outcome: .brokenByRevoke,
            appVersion: "test"
        )
    }

    static func active(startedAt: Date) -> SessionRecord {
        SessionRecord(
            id: UUID(),
            blocklistId: fixedBlocklistId,
            startedAt: startedAt,
            plannedEndAt: startedAt.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            actualEndAt: nil,
            outcome: nil,
            appVersion: "test"
        )
    }

    /// Malformed: outcome == .completed but actualEndAt == nil. Shouldn't exist in
    /// practice (Phase 3 invariant) but we test defensive ignoring.
    static func malformedCompletedWithoutEndDate() -> SessionRecord {
        SessionRecord(
            id: UUID(),
            blocklistId: fixedBlocklistId,
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            plannedEndAt: Date(timeIntervalSinceReferenceDate: 1800),
            plannedDurationSeconds: 1800,
            actualEndAt: nil,
            outcome: .completed,
            appVersion: "test"
        )
    }

    /// Build a deterministic PL/Gregorian calendar for tests. `firstWeekday = 2` (Monday).
    static func polishCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        cal.firstWeekday = 2
        cal.locale = Locale(identifier: "pl_PL")
        return cal
    }

    /// Construct a Date from YMD + hour in the Polish calendar.
    static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12, calendar: Calendar = polishCalendar()) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = hour; comps.minute = 0
        return calendar.date(from: comps)!
    }
}
