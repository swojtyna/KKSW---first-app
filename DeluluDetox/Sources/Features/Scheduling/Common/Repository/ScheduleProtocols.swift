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

protocol ObserveScheduleUseCase: Sendable {
    func execute() -> AnyPublisher<[Schedule], Never>
}

protocol CreateOrUpdateScheduleUseCase: Sendable {
    func execute(_ schedule: Schedule) async throws
}

protocol ToggleScheduleUseCase: Sendable {
    func execute(scheduleId: UUID, enabled: Bool) async throws
}

protocol SyncScheduleWithSystemUseCase: Sendable {
    func execute(schedule: Schedule) async throws
}

protocol SelfHealSchedulesUseCase: Sendable {
    /// Reconciles persisted schedules with the current shield state on app
    /// foreground (CONTEXT §D-18). Returns the number of shield operations
    /// (apply/clear) actually performed — zero when every schedule's
    /// computed window matches its last-applied flag.
    @discardableResult
    func execute(now: Date) async throws -> Int
}

protocol ComputeScheduleWindowUseCase: Sendable {
    func execute(schedule: Schedule, now: Date, calendar: Calendar) -> ScheduleWindow
}

/// Pure value emitted by `ComputeScheduleWindowUseCase`. Encodes "is this
/// schedule supposed to be blocking right now, and if so until when?" so
/// `SelfHealSchedulesUseCase` can decide apply/clear without re-deriving
/// time math.
struct ScheduleWindow: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case active(endsAt: Date)
        case upcomingToday(startsAt: Date)
        case notToday(nextDate: Date?)
        case inactive
    }

    let state: State
    let currentWeekday: Int // 1..7 (Calendar.weekday). 0 when schedule disabled.
}

/// Errors raised by the coordination UseCases (`ToggleScheduleUseCase`,
/// `SelfHealSchedulesUseCase`) when pre-conditions fail.
enum ScheduleUseCaseError: Error {
    case scheduleNotFound
    case blocklistMissing
}

protocol ConsumeScheduleEventMarkerUseCase: Sendable {
    /// Count of markers consumed (appended to events.json + deleted).
    @discardableResult
    func execute() async throws -> Int
}
