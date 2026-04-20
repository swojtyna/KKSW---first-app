import Foundation
import os

/// CONTEXT §D-08 end sequence. Idempotent and defense-in-depth:
///
/// - Always calls `shield.clearShield()` + `monitoring.stopActivityMonitoring()`
///   BEFORE the repository finalize. Even if there is no active session record,
///   clearing stale shield state is the safer default (a shield that outlives
///   its session is a user-visible bug; a no-op clear is harmless).
/// - Swallows `SessionStoreError.noActiveSession` from the repository — it just
///   means the in-memory subject had no active record (already finalized or
///   never started). All other errors propagate.
protocol EndSessionUseCase: Sendable {
    func callAsFunction(outcome: SessionOutcome, actualEndAt: Date) async throws
}

final class EndSessionUseCaseImpl: EndSessionUseCase, @unchecked Sendable {
    private let repository: SessionRepository
    private let shield: SessionShieldRepository
    private let monitoring: SessionActivityMonitoringRepository

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "EndSessionUC"
    )

    init(
        repository: SessionRepository,
        shield: SessionShieldRepository,
        monitoring: SessionActivityMonitoringRepository
    ) {
        self.repository = repository
        self.shield = shield
        self.monitoring = monitoring
    }

    func callAsFunction(outcome: SessionOutcome, actualEndAt: Date) async throws {
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
}
