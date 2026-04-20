@preconcurrency import DeviceActivity
import Foundation
import os

// MARK: - Implementation

/// Plan 05-03 — DAS registration for recurring schedules.
///
/// Mirrors `LiveSessionActivityMonitoringRepository` in structure but:
///  - Registers 1 (single-day) or 2 (cross-midnight) DAS per schedule
///    via `Schedule.buildDeviceActivitySchedules()` (RESEARCH Example 1).
///  - `stopMonitoring(scheduleId:)` passes ALL THREE segment variants
///    defensively — iOS ignores names that were never registered, so this
///    keeps a prior single-day ↔ cross-midnight edit from leaking a stale
///    segment into the 20-activity budget (pitfall D-14 #1).
///
/// The `DeviceActivityCenterRunner` / `LiveDeviceActivityCenterRunner` types
/// are REUSED from Phase 4 (see `Features/Session/Repository/SessionActivityMonitoringRepository.swift`).
/// This file deliberately does NOT redefine them.
final class LiveScheduleActivityMonitoringRepository: ScheduleActivityMonitoringRepository, @unchecked Sendable {
    private let runner: DeviceActivityCenterRunner

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "ScheduleActivityMonitoring"
    )

    /// Production convenience init — uses the real `DeviceActivityCenter`.
    convenience init() {
        self.init(runner: LiveDeviceActivityCenterRunner())
    }

    /// Test seam — accepts a protocol-wrapped runner double.
    init(runner: DeviceActivityCenterRunner) {
        self.runner = runner
    }

    func startMonitoring(schedule: Schedule) async throws {
        let pairs = schedule.buildDeviceActivitySchedules()
        for pair in pairs {
            do {
                try runner.startMonitoring(pair.name, during: pair.schedule)
                Self.log.info(
                    "schedule monitoring started name=\(pair.name.rawValue, privacy: .public)"
                )
            } catch {
                Self.log.error(
                    "startMonitoring failed name=\(pair.name.rawValue, privacy: .public): \(String(describing: error), privacy: .public)"
                )
                throw ScheduleActivityMonitoringError.startFailed(error)
            }
        }
    }

    func stopMonitoring(scheduleId: UUID) async {
        // Defensive clear of all three segment variants — see class doc comment
        // and CONTEXT §D-14 pitfall #1. Order does not matter; iOS
        // stopMonitoring silently ignores unknown names.
        let names: [DeviceActivityName] = [ScheduleSegment.main, .evening, .morning].map {
            ScheduleActivityNames.activityName(scheduleId: scheduleId, segment: $0)
        }
        runner.stopMonitoring(names)
        Self.log.info(
            "schedule monitoring stopped id=\(scheduleId.uuidString, privacy: .public)"
        )
    }
}
