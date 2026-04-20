@preconcurrency import DeviceActivity
import Foundation

extension Schedule {
    /// Returns 1 (single-day) or 2 (cross-midnight) `(name, das)` pairs ready
    /// for `DeviceActivityCenter.startMonitoring(_:during:)`.
    ///
    /// - Single-day (`crossesMidnight == false`):
    ///   one DAS named `.main`, intervalStart = (startHour, startMinute),
    ///   intervalEnd = (endHour, endMinute).
    /// - Cross-midnight (D-03):
    ///   `.evening` DAS (intervalStart → 23:59:59) + `.morning` DAS (00:00:00 → intervalEnd).
    ///
    /// Every DAS uses `repeats: true` per Wave 0 Outcome A (see 05-DISCUSSION-LOG.md).
    /// Weekday filtering is NOT encoded in the DAS — DAM extension (Plan 05-05)
    /// filters on `Calendar.weekday` at `intervalDidStart` time (D-13).
    ///
    /// Reference: RESEARCH §Example 1.
    func buildDeviceActivitySchedules() -> [(name: DeviceActivityName, schedule: DeviceActivitySchedule)] {
        if !crossesMidnight {
            let name = ScheduleActivityNames.activityName(scheduleId: id, segment: .main)
            let das = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: startHour, minute: startMinute),
                intervalEnd: DateComponents(hour: endHour, minute: endMinute, second: 0),
                repeats: true
            )
            return [(name: name, schedule: das)]
        }

        // Cross-midnight split (D-03): two back-to-back windows in Calendar time.
        let eveningName = ScheduleActivityNames.activityName(scheduleId: id, segment: .evening)
        let eveningDAS = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: startHour, minute: startMinute),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        let morningName = ScheduleActivityNames.activityName(scheduleId: id, segment: .morning)
        let morningDAS = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: endHour, minute: endMinute, second: 0),
            repeats: true
        )
        return [
            (name: eveningName, schedule: eveningDAS),
            (name: morningName, schedule: morningDAS)
        ]
    }
}
