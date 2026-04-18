import DeviceActivity
import os

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox.DeviceActivityMonitorExtension",
        category: "Monitor"
    )

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.info("intervalDidStart: \(activity.rawValue, privacy: .public)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.info("intervalDidEnd: \(activity.rawValue, privacy: .public)")
    }
}
