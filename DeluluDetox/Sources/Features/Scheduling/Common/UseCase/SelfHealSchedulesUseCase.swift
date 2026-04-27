import Combine
import Foundation
import os

/// CONTEXT §D-18 — on app foreground, reconcile persisted schedules against
/// the current shield state. Handles the "DAM callback missed" failure mode
/// (iOS 26 reliability risk per PROJECT.md blockers) — if the computed window
/// says we should be blocking but no last-applied flag exists, we apply;
/// conversely, if we stored an active flag but the window is no longer
/// active, we clear.
///
/// Last-applied state is persisted in a dedicated `UserDefaults` suite
/// (`ComputeScheduleWindowUseCaseImpl.scheduleStateSuiteName`) so the flag
/// survives app relaunch. Overridable via `defaultsOverride` test seam.
final class SelfHealSchedulesUseCaseImpl: SelfHealSchedulesUseCase, @unchecked Sendable {
    private let scheduleRepo: ScheduleRepository
    private let shieldRepo: ScheduleShieldRepository
    private let observeBlocklist: ObserveBlocklistUseCase
    private let compute: ComputeScheduleWindowUseCase
    private let calendar: Calendar
    private let defaults: UserDefaults
    private static let log = Logger(subsystem: "com.kksw.DeluluDetox", category: "SelfHealSchedulesUseCase")

    /// Test seam — overrides the UserDefaults suite used to track last-applied
    /// flags. Same pattern as Phase 3 `MarkSuccessShownUseCase`.
    nonisolated(unsafe) static var defaultsOverride: UserDefaults?

    init(
        scheduleRepo: ScheduleRepository,
        shieldRepo: ScheduleShieldRepository,
        observeBlocklist: ObserveBlocklistUseCase,
        compute: ComputeScheduleWindowUseCase,
        calendar: Calendar = .current
    ) {
        self.scheduleRepo = scheduleRepo
        self.shieldRepo = shieldRepo
        self.observeBlocklist = observeBlocklist
        self.compute = compute
        self.calendar = calendar
        self.defaults = Self.defaultsOverride
            ?? UserDefaults(suiteName: ComputeScheduleWindowUseCaseImpl.scheduleStateSuiteName)
            ?? .standard
    }

    @discardableResult
    func execute(now: Date) async throws -> Int {
        let schedules = await currentSchedules()
        let enabled = schedules.filter { $0.enabled }
        guard !enabled.isEmpty else { return 0 }

        let blocklist = await currentBlocklist()
        let blocklistAvailable = !blocklist.records.isEmpty

        var operations = 0
        for schedule in enabled {
            let window = compute.execute(schedule: schedule, now: now, calendar: calendar)
            let shouldBeActive: Bool = {
                if case .active = window.state { return true }
                return false
            }()
            let key = ComputeScheduleWindowUseCaseImpl.lastAppliedKey(scheduleId: schedule.id)
            let wasApplied = defaults.bool(forKey: key)

            switch (shouldBeActive, wasApplied) {
            case (true, false):
                // Need a non-empty blocklist to apply. If missing, skip apply
                // but keep iterating — other schedules may still need clear.
                guard blocklistAvailable else {
                    Self.log.info("blocklist empty — skipping apply id=\(schedule.id.uuidString, privacy: .public)")
                    continue
                }
                try await shieldRepo.applyShield(for: blocklist)
                defaults.set(true, forKey: key)
                operations += 1
                Self.log.info("self-heal applied id=\(schedule.id.uuidString, privacy: .public)")
            case (false, true):
                await shieldRepo.clearShield()
                defaults.set(false, forKey: key)
                operations += 1
                Self.log.info("self-heal cleared id=\(schedule.id.uuidString, privacy: .public)")
            default:
                break
            }
        }
        return operations
    }

    private func currentSchedules() async -> [Schedule] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[Schedule], Never>) in
            var cancellable: AnyCancellable?
            cancellable = scheduleRepo.schedulesPublisher.first().sink { schedules in
                continuation.resume(returning: schedules)
                cancellable?.cancel()
            }
        }
    }

    private func currentBlocklist() async -> Blocklist {
        await withCheckedContinuation { (continuation: CheckedContinuation<Blocklist, Never>) in
            var cancellable: AnyCancellable?
            cancellable = observeBlocklist.execute().first().sink { blocklist in
                continuation.resume(returning: blocklist)
                cancellable?.cancel()
            }
        }
    }
}
