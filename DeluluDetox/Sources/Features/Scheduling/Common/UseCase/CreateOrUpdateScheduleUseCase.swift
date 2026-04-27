import Foundation
import os

/// Editor "Save" path. Persists the schedule via the repository, then
/// delegates to the Sync UC (Plan 04 will fill its body). Rollback
/// semantics live in Plan 04 per CONTEXT §D-14 — Plan 05-02 only wires
/// the two calls in the documented order.
final class CreateOrUpdateScheduleUseCaseImpl: CreateOrUpdateScheduleUseCase, @unchecked Sendable {
    private let repository: ScheduleRepository
    private let sync: SyncScheduleWithSystemUseCase

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "CreateOrUpdateScheduleUseCase"
    )

    init(repository: ScheduleRepository, sync: SyncScheduleWithSystemUseCase) {
        self.repository = repository
        self.sync = sync
    }

    func execute(_ schedule: Schedule) async throws {
        try await repository.upsert(schedule)
        Self.log.info(
            "schedule upserted id=\(schedule.id.uuidString, privacy: .public) enabled=\(schedule.enabled, privacy: .public)"
        )
        // Delegate to Sync UC. Plan 04 owns DAS rollback (CONTEXT §D-14);
        // Plan 02 merely composes the two calls in order.
        try await sync.execute(schedule: schedule)
    }
}
