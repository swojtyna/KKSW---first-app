@preconcurrency import DeviceActivity
import Foundation

/// DeviceActivity name namespace for Phase 5 schedules.
/// Format: `"deluludetox.schedule.{uuidString}.{segment.rawValue}"`.
///
/// Both main app (DeviceActivityCenter registration) and DAM extension
/// (intervalDidStart / intervalDidEnd dispatch) use the same builder + parser
/// so names never drift between the two processes.
enum ScheduleActivityNames {
    static let prefix = "deluludetox.schedule."

    static func activityName(scheduleId: UUID, segment: ScheduleSegment) -> DeviceActivityName {
        DeviceActivityName("\(prefix)\(scheduleId.uuidString).\(segment.rawValue)")
    }

    /// Returns nil if the activity name is not a Scheduling activity.
    static func parse(_ name: DeviceActivityName) -> (scheduleId: UUID, segment: ScheduleSegment)? {
        let raw = name.rawValue
        guard raw.hasPrefix(prefix) else { return nil }
        let parts = raw.split(separator: ".")
        // Expected: ["deluludetox", "schedule", "{uuid}", "{segment}"]
        guard parts.count == 4 else { return nil }
        guard let scheduleId = UUID(uuidString: String(parts[2])) else { return nil }
        guard let segment = ScheduleSegment(rawValue: String(parts[3])) else { return nil }
        return (scheduleId, segment)
    }
}
