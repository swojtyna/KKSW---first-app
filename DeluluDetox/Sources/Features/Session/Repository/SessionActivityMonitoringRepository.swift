@preconcurrency import DeviceActivity
import Foundation
import os

// MARK: - Errors

enum SessionActivityMonitoringError: Error {
    case deviceActivityStartFailed(Error)
}

// MARK: - Protocol

/// Data-layer facade over `DeviceActivityCenter` for session monitoring.
/// Split from the legacy `SessionEnforcer` to honor the "1 aggregate = 1 repository"
/// rule — DeviceActivity scheduling is a separate aggregate from shield writes.
protocol SessionActivityMonitoringRepository: Sendable {
    /// Schedule a non-repeating DeviceActivitySchedule terminating at
    /// `session.plannedEndAt`. The DAM extension receives `intervalDidEnd`.
    func startActivityMonitoring(for session: SessionRecord) async throws

    /// Stop monitoring the quick-session activity. No-op if not monitoring.
    func stopActivityMonitoring() async
}

// MARK: - Internal seam (testable)

/// Narrow facet of DeviceActivityCenter used by the repository. Same rationale
/// as `ManagedSettingsStoreWriter` — keep the seam small and testable.
protocol DeviceActivityCenterRunner: AnyObject, Sendable {
    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}

// MARK: - Production adapter

final class LiveDeviceActivityCenterRunner: DeviceActivityCenterRunner, @unchecked Sendable {
    private let center = DeviceActivityCenter()

    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws {
        try center.startMonitoring(activity, during: schedule)
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        center.stopMonitoring(activities)
    }
}

// MARK: - Implementation

final class LiveSessionActivityMonitoringRepository: SessionActivityMonitoringRepository, @unchecked Sendable {
    private let center: DeviceActivityCenterRunner

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "SessionActivityMonitoring"
    )

    /// Production convenience init uses the real DeviceActivityCenter runner.
    convenience init() {
        self.init(center: LiveDeviceActivityCenterRunner())
    }

    /// Test seam — accepts a protocol-wrapped runner double.
    init(center: DeviceActivityCenterRunner) {
        self.center = center
    }

    func startActivityMonitoring(for session: SessionRecord) async throws {
        // Include date components — without .year/.month/.day, sessions that cross
        // midnight produce endComponents.hour < startComponents.hour, which makes
        // DeviceActivitySchedule either reject the registration or fire
        // intervalDidEnd immediately. The same silent-failure shape as a sub-15-min
        // schedule. Always carry the absolute start/end calendar instants.
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let startComponents = Calendar.current.dateComponents(components, from: session.startedAt)
        let endComponents = Calendar.current.dateComponents(components, from: session.plannedEndAt)
        // One-shot schedule: repeats=false fires intervalDidEnd exactly once (CONTEXT §D-01).
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        do {
            try center.startMonitoring(SessionActivityNames.quickSession, during: schedule)
            Self.log.info(
                "activity monitoring started id=\(session.id.uuidString, privacy: .public) end=\(session.plannedEndAt.timeIntervalSince1970, privacy: .public)"
            )
        } catch {
            Self.log.error("startMonitoring failed: \(String(describing: error), privacy: .public)")
            throw SessionActivityMonitoringError.deviceActivityStartFailed(error)
        }
    }

    func stopActivityMonitoring() async {
        center.stopMonitoring([SessionActivityNames.quickSession])
        Self.log.info("activity monitoring stopped")
    }
}
