import Combine
import Foundation
import os

/// CONTEXT §D-02 expired-active-session recovery.
///
/// If the repository's active session has `plannedEndAt` in the past (e.g. the
/// device was off / main-app not launched when DAM would've fired), finalize
/// the session with `.completed` and `actualEndAt = plannedEndAt` (we cap at
/// the planned end — never report a wall-clock-now that the user wouldn't
/// have seen live).
///
/// Returns `true` iff a finalize actually happened.
protocol SelfHealExpiredSessionUseCase: Sendable {
    func execute(now: Date) async throws -> Bool
}

final class SelfHealExpiredSessionUseCaseImpl: SelfHealExpiredSessionUseCase, @unchecked Sendable {
    private let repository: SessionRepository
    private let endSession: EndSessionUseCase

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "SelfHealUC"
    )

    init(repository: SessionRepository, endSession: EndSessionUseCase) {
        self.repository = repository
        self.endSession = endSession
    }

    func execute(now: Date) async throws -> Bool {
        let active = await currentActive()
        guard let active, active.plannedEndAt < now else {
            return false
        }
        Self.log.info("self-heal firing: active.plannedEndAt < now for id=\(active.id.uuidString, privacy: .public)")
        // Cap actualEndAt at plannedEndAt — don't report wall-clock-now as the session's end.
        try await endSession.execute(outcome: .completed, actualEndAt: active.plannedEndAt)
        return true
    }

    // MARK: - Private

    private func currentActive() async -> SessionRecord? {
        await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = repository.activeSessionPublisher
                .first()
                .sink { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
        }
    }
}
