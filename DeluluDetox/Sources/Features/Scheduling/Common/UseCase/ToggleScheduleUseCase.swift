import Combine
import Foundation
import os

/// CONTEXT §D-11 — enable/disable toggle semantics.
///
/// Flips `schedule.enabled`, persists via `repository.upsert`, then delegates
/// to `SyncScheduleWithSystemUseCase` which registers / stops the system DAS.
///
/// The sync UC enforces the "disable doesn't force-clear current shield"
/// policy (D-11 — current window drains via intervalDidEnd or self-heal).
/// This UC throws `ScheduleUseCaseError.scheduleNotFound` if the caller
/// passes an unknown id — typically a race with remove() on another thread.
final class ToggleScheduleUseCaseImpl: ToggleScheduleUseCase, @unchecked Sendable {
    private let repository: ScheduleRepository
    private let sync: SyncScheduleWithSystemUseCase

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "ToggleScheduleUseCase"
    )

    init(repository: ScheduleRepository, sync: SyncScheduleWithSystemUseCase) {
        self.repository = repository
        self.sync = sync
    }

    func execute(scheduleId: UUID, enabled: Bool) async throws {
        let current = await findSchedule(scheduleId)
        guard let existing = current else {
            Self.log.error("toggle failed — schedule not found id=\(scheduleId.uuidString, privacy: .public)")
            throw ScheduleUseCaseError.scheduleNotFound
        }

        var updated = existing
        updated.enabled = enabled

        try await repository.upsert(updated)
        try await sync.execute(schedule: updated)
        Self.log.info(
            "schedule toggled id=\(scheduleId.uuidString, privacy: .public) enabled=\(enabled, privacy: .public)"
        )
    }

    // MARK: - Private

    private func findSchedule(_ id: UUID) async -> Schedule? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Schedule?, Never>) in
            var cancellable: AnyCancellable?
            cancellable = repository.schedulesPublisher.first().sink { schedules in
                continuation.resume(returning: schedules.first(where: { $0.id == id }))
                cancellable?.cancel()
            }
        }
    }
}
