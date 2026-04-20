import Combine
import Foundation
import os

/// CONTEXT §D-14 — "editor save → sync with iOS" entry point.
///
/// Contract (happy path per Wave 0 Outcome A):
///   1. Stop any DAS already registered for this scheduleId (all 3 segment
///      variants — see `LiveScheduleActivityMonitoringRepository`).
///   2. If `schedule.enabled == false`, we're done. D-11: disabling doesn't
///      imperatively clear the current shield; it only ensures no *future*
///      intervalDidStart fires. The currently-armed store clears on the next
///      DAM `intervalDidEnd` or on scenePhase.active self-heal.
///   3. Otherwise, register new DAS via `startMonitoring(schedule:)`.
///
/// Rollback semantics (D-14 step 5):
///   If startMonitoring throws, best-effort re-persist the *prior* snapshot
///   of this schedule (read from the repository's in-memory subject before
///   stopping). The caller sees the original error rethrown so the editor
///   can surface a sarcastic error toast ("iOS się zbuntował, spróbuj
///   jeszcze raz"). If the prior snapshot upsert itself throws, we swallow
///   that error — the user's original failure is what matters.
final class SyncScheduleWithSystemUseCaseImpl: SyncScheduleWithSystemUseCase, @unchecked Sendable {
    private let monitoring: ScheduleActivityMonitoringRepository
    private let repository: ScheduleRepository

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "SyncScheduleWithSystemUseCase"
    )

    init(monitoring: ScheduleActivityMonitoringRepository, repository: ScheduleRepository) {
        self.monitoring = monitoring
        self.repository = repository
    }

    func callAsFunction(schedule: Schedule) async throws {
        // Snapshot prior state for rollback. Read BEFORE stopMonitoring so a
        // race between editor-save and DAM-fire can't corrupt the snapshot.
        let priorSnapshot = await currentSnapshot(for: schedule.id)

        // Step 1: stop any existing DAS (all 3 segment variants).
        await monitoring.stopMonitoring(scheduleId: schedule.id)

        // Step 2: disabled → we're done.
        guard schedule.enabled else {
            Self.log.info("schedule disabled id=\(schedule.id.uuidString, privacy: .public)")
            return
        }

        // Step 3: register new DAS.
        do {
            try await monitoring.startMonitoring(schedule: schedule)
            Self.log.info("schedule synced id=\(schedule.id.uuidString, privacy: .public) enabled=true")
        } catch {
            Self.log.error(
                "startMonitoring failed id=\(schedule.id.uuidString, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            if let prior = priorSnapshot {
                try? await repository.upsert(prior)
                Self.log.info("rolled back schedule.json to prior snapshot id=\(schedule.id.uuidString, privacy: .public)")
            }
            throw error
        }
    }

    // MARK: - Private

    private func currentSnapshot(for id: UUID) async -> Schedule? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Schedule?, Never>) in
            var cancellable: AnyCancellable?
            cancellable = repository.schedulesPublisher.first().sink { schedules in
                continuation.resume(returning: schedules.first(where: { $0.id == id }))
                cancellable?.cancel()
            }
        }
    }
}
