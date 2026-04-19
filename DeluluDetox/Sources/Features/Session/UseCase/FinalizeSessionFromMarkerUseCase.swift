import Combine
import Foundation
import os

/// Reconciles the DAM-written `SessionFinalizeMarker` with the main-app
/// `SessionRepository` active session. Idempotent — re-invoking with no marker
/// or a stale (mismatched id) marker returns `false` without side effects on
/// the session state (the stale marker file IS destructively consumed).
///
/// Returns `true` iff a finalize actually happened.
protocol FinalizeSessionFromMarkerUseCase: Sendable {
    func callAsFunction(now: Date) async throws -> Bool
}

final class FinalizeSessionFromMarkerUseCaseImpl: FinalizeSessionFromMarkerUseCase, @unchecked Sendable {
    private let repository: SessionRepository
    private let endSession: EndSessionUseCase

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "FinalizeFromMarkerUC"
    )

    init(repository: SessionRepository, endSession: EndSessionUseCase) {
        self.repository = repository
        self.endSession = endSession
    }

    func callAsFunction(now: Date) async throws -> Bool {
        guard let marker = try await repository.consumeFinalizeMarker() else {
            return false
        }

        let active = await currentActive()

        guard let active, active.id == marker.sessionId else {
            Self.log.info("marker ignored (stale or no active) markerId=\(marker.sessionId.uuidString, privacy: .public)")
            return false
        }

        try await endSession(outcome: .completed, actualEndAt: min(now, active.plannedEndAt))
        Self.log.info("finalized via marker id=\(active.id.uuidString, privacy: .public)")
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
