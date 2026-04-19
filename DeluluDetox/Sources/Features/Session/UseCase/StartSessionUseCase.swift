import Combine
import Foundation
import os

/// CONTEXT §D-07 atomic session start.
///
/// Step 1: Persist a new SessionRecord via `SessionRepository.startSession`.
/// Step 2: Apply ManagedSettings shield via `SessionEnforcer.applyShield(for:)`.
/// Step 3: Schedule DeviceActivity monitoring via `SessionEnforcer.startActivityMonitoring`.
///
/// If step 2 OR step 3 throws, best-effort rollback fires: clearShield +
/// stopActivityMonitoring + repo.finalizeActiveSession(.cancelledByUser). The
/// original error rethrows after rollback so callers can surface a UI-visible failure.
protocol StartSessionUseCase: Sendable {
    func callAsFunction(
        blocklistId: UUID,
        duration: SessionDuration,
        now: Date
    ) async throws -> SessionRecord
}

final class StartSessionUseCaseImpl: StartSessionUseCase, @unchecked Sendable {
    private let repository: SessionRepository
    private let enforcer: SessionEnforcer
    private let observeBlocklist: ObserveBlocklistUseCase

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "StartSessionUC"
    )

    init(
        repository: SessionRepository,
        enforcer: SessionEnforcer,
        observeBlocklist: ObserveBlocklistUseCase
    ) {
        self.repository = repository
        self.enforcer = enforcer
        self.observeBlocklist = observeBlocklist
    }

    func callAsFunction(
        blocklistId: UUID,
        duration: SessionDuration,
        now: Date
    ) async throws -> SessionRecord {
        // Step 1: persist the active record (CONTEXT §D-07 step 1).
        let record = try await repository.startSession(
            blocklistId: blocklistId,
            duration: duration,
            now: now
        )

        // Resolve the current Blocklist snapshot for the shield application.
        let blocklist = await currentBlocklistSnapshot()

        // Step 2: apply shield + system restrictions (CONTEXT §D-07 steps 2 + 4).
        do {
            try await enforcer.applyShield(for: blocklist)
        } catch {
            Self.log.error("applyShield failed: \(String(describing: error), privacy: .public) — rolling back")
            await rollback(recordID: record.id, actualEndAt: now)
            throw error
        }

        // Step 3: start activity monitoring (CONTEXT §D-07 step 3).
        do {
            try await enforcer.startActivityMonitoring(for: record)
        } catch {
            Self.log.error("startActivityMonitoring failed: \(String(describing: error), privacy: .public) — rolling back")
            await rollback(recordID: record.id, actualEndAt: now)
            throw error
        }

        Self.log.info("session started id=\(record.id.uuidString, privacy: .public)")
        return record
    }

    // MARK: - Private

    private func currentBlocklistSnapshot() async -> Blocklist {
        await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = observeBlocklist()
                .first()
                .sink { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
        }
    }

    private func rollback(recordID: UUID, actualEndAt: Date) async {
        await enforcer.clearShield()
        await enforcer.stopActivityMonitoring()
        // Finalize the just-created record as cancelled (user never saw a live session).
        try? await repository.finalizeActiveSession(
            outcome: .cancelledByUser,
            actualEndAt: actualEndAt
        )
    }
}
