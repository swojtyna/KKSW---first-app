import Combine
import Foundation
import os

/// CONTEXT §D-08 end sequence. Idempotent and defense-in-depth:
///
/// - Phase 6 §H2 (NTF-01): when `outcome != .completed`, reads the active
///   session id BEFORE finalize clears the subject and cancels the pending
///   `session.end.{uuid}` UNNotificationRequest. When outcome == .completed,
///   iOS fires the already-scheduled notification naturally — we leave it.
/// - Always calls `shield.clearShield()` + `monitoring.stopActivityMonitoring()`
///   BEFORE the repository finalize. Even if there is no active session record,
///   clearing stale shield state is the safer default (a shield that outlives
///   its session is a user-visible bug; a no-op clear is harmless).
/// - Swallows `SessionStoreError.noActiveSession` from the repository — it just
///   means the in-memory subject had no active record (already finalized or
///   never started). All other errors propagate.
protocol EndSessionUseCase: Sendable {
    func execute(outcome: SessionOutcome, actualEndAt: Date) async throws
}

final class EndSessionUseCaseImpl: EndSessionUseCase, @unchecked Sendable {
    private let repository: SessionRepository
    private let shield: SessionShieldRepository
    private let monitoring: SessionActivityMonitoringRepository
    private let cancelEndNotification: CancelSessionEndNotificationUseCase

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "EndSessionUC"
    )

    init(
        repository: SessionRepository,
        shield: SessionShieldRepository,
        monitoring: SessionActivityMonitoringRepository,
        cancelEndNotification: CancelSessionEndNotificationUseCase
    ) {
        self.repository = repository
        self.shield = shield
        self.monitoring = monitoring
        self.cancelEndNotification = cancelEndNotification
    }

    func execute(outcome: SessionOutcome, actualEndAt: Date) async throws {
        // Phase 6 §H2: read active id BEFORE finalize (finalize clears the subject).
        // Only cancel the pending NTF-01 when outcome is abort-like; iOS fires
        // the pending trigger naturally on `.completed`.
        if outcome != .completed, let activeId = await currentActiveId() {
            await cancelEndNotification.execute(sessionId: activeId)
        }

        // Defense-in-depth: always clear shield + stop monitoring, even if there is
        // no active repo record (stale state recovery). CONTEXT §D-08.
        await shield.clearShield()
        await monitoring.stopActivityMonitoring()

        do {
            try await repository.finalizeActiveSession(outcome: outcome, actualEndAt: actualEndAt)
            Self.log.info("session ended outcome=\(outcome.rawValue, privacy: .public)")
        } catch SessionStoreError.noActiveSession {
            // No-op — stale state was already cleared above.
            Self.log.info("endSession called without active record (no-op)")
        } catch {
            Self.log.error("endSession failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    // MARK: - Private

    private func currentActiveId() async -> UUID? {
        await withCheckedContinuation { (continuation: CheckedContinuation<UUID?, Never>) in
            var cancellable: AnyCancellable?
            cancellable = repository.activeSessionPublisher
                .first()
                .sink { value in
                    continuation.resume(returning: value?.id)
                    cancellable?.cancel()
                }
        }
    }
}
