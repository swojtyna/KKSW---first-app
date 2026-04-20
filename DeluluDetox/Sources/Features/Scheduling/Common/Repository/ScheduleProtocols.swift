// Features/Scheduling/Common/Repository/ScheduleProtocols.swift
//
// Empty Scheduling protocols declared up-front so Plan 05-01 test mocks
// compile against real type names. Plans 05-02 / 05-03 / 05-04 REPLACE
// the empty protocol bodies with the actual method declarations.
//
// Downstream plans must NOT create new files for these protocols — they
// extend the declarations below in-place so conformers (Live* + Mock*)
// stay in sync automatically.

import Combine
import Foundation

protocol ScheduleRepository: Sendable {
    var schedulesPublisher: AnyPublisher<[Schedule], Never> { get }
    func upsert(_ schedule: Schedule) async throws
    func remove(id: UUID) async throws
    func loadFromDisk() async throws -> [Schedule]
    func appendEvent(_ event: ScheduleEvent) async throws
    /// RESEARCH OQ#4 — consume all timestamp-suffixed marker files at once.
    /// Returns them sorted ascending by timestamp; deletes each from disk
    /// after decoding so cross-midnight (evening-start + morning-end)
    /// cannot lose an event when the app is not foregrounded between them.
    func consumeEventMarkers() async throws -> [ScheduleEventMarker]
}

protocol ScheduleShieldRepository: Sendable {
    /// Apply shield from blocklist selection to the `deluludetox.schedule`
    /// named store (D-05). Also sets `requireAutomaticDateAndTime = true`
    /// (clock-skew bypass defense — RESEARCH §Threat Patterns).
    ///
    /// Deliberately does NOT touch `denyAppRemoval` — schedules are user-
    /// reconfigurable by design (D-11 disable-from-next-window); removing
    /// the app during an active schedule is an acceptable eject.
    func applyShield(for blocklist: Blocklist) async throws

    /// Clear the schedule-named store only. Session store is untouched (D-05).
    func clearShield() async
}

protocol ScheduleActivityMonitoringRepository: Sendable {
    /// Register 1 (single-day) or 2 (cross-midnight) `DeviceActivitySchedule`s
    /// for the supplied schedule. Uses `ScheduleActivityNames` + `ScheduleSegment`
    /// so DAM callbacks can parse back to `(scheduleId, segment)`.
    /// Throws `ScheduleActivityMonitoringError.startFailed` on DAC failure.
    func startMonitoring(schedule: Schedule) async throws

    /// Defensively stops ALL three segment variants (.main / .evening / .morning)
    /// so edits that flip single-day ↔ cross-midnight never leave a stale
    /// segment consuming the 20-activity budget (pitfall D-14 #1). iOS ignores
    /// names that were never registered.
    func stopMonitoring(scheduleId: UUID) async
}

/// Errors raised by `ScheduleActivityMonitoringRepository.startMonitoring`.
/// Plan 05-04 `SyncScheduleWithSystemUseCase` unwraps `startFailed` to roll
/// back the JSON write and surface a sarcastic error toast (D-14).
enum ScheduleActivityMonitoringError: Error {
    case startFailed(Error)
}

protocol ObserveScheduleUseCase: Sendable {}

protocol CreateOrUpdateScheduleUseCase: Sendable {
    func callAsFunction(_ schedule: Schedule) async throws
}

protocol ToggleScheduleUseCase: Sendable {}

protocol SyncScheduleWithSystemUseCase: Sendable {
    func callAsFunction(schedule: Schedule) async throws
}

protocol SelfHealSchedulesUseCase: Sendable {}

protocol ComputeScheduleWindowUseCase: Sendable {}

protocol ConsumeScheduleEventMarkerUseCase: Sendable {
    /// Count of markers consumed (appended to events.json + deleted).
    @discardableResult
    func callAsFunction() async throws -> Int
}
