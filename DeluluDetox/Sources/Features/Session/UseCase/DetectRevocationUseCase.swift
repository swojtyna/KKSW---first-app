import Combine
@preconcurrency import FamilyControls
import Foundation
import os

/// CONTEXT §D-11 revocation detection.
///
/// If an active session exists AND `AuthorizationCenter.shared.authorizationStatus`
/// reports anything other than `.approved`, finalize the session with
/// `.brokenByRevoke`. Returns `true` iff a finalize happened.
///
/// ### MainActor hop
/// Production reads `AuthorizationCenter.shared.authorizationStatus` on MainActor
/// because Phase 02-07 device UAT crashed in EXC_BREAKPOINT when that exact access
/// happened on a non-MainActor task (Screen Time API SDK has implicit MainActor
/// isolation on its stored properties that only surfaces at runtime on-device).
/// `@preconcurrency import FamilyControls` keeps the compiler quiet while we
/// enforce the hop at the call site.
protocol DetectRevocationUseCase: Sendable {
    func callAsFunction(now: Date) async throws -> Bool
}

final class DetectRevocationUseCaseImpl: DetectRevocationUseCase, @unchecked Sendable {
    private let repository: SessionRepository
    private let endSession: EndSessionUseCase
    private let authorizationStatusProvider: @Sendable () async -> AuthorizationStatus

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "DetectRevocationUC"
    )

    /// Production convenience — reads `AuthorizationCenter.shared.authorizationStatus` on MainActor.
    convenience init(repository: SessionRepository, endSession: EndSessionUseCase) {
        self.init(
            repository: repository,
            endSession: endSession,
            authorizationStatusProvider: {
                await MainActor.run { AuthorizationCenter.shared.authorizationStatus }
            }
        )
    }

    init(
        repository: SessionRepository,
        endSession: EndSessionUseCase,
        authorizationStatusProvider: @escaping @Sendable () async -> AuthorizationStatus
    ) {
        self.repository = repository
        self.endSession = endSession
        self.authorizationStatusProvider = authorizationStatusProvider
    }

    func callAsFunction(now: Date) async throws -> Bool {
        let active = await currentActive()
        guard active != nil else { return false }

        let status = await authorizationStatusProvider()
        guard status != .approved else { return false }

        Self.log.info("revocation detected status=\(String(describing: status), privacy: .public) — finalizing session")
        try await endSession(outcome: .brokenByRevoke, actualEndAt: now)
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
