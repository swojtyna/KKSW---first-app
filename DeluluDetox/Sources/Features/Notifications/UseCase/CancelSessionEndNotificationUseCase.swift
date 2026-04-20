import Foundation
import os

/// NTF-01 cancel hook (CONTEXT §D-16).
/// Called from `EndSessionUseCaseImpl.callAsFunction` BEFORE
/// `repository.finalizeActiveSession` (otherwise the active-session id is lost).
/// Only invoked when `outcome != .completed`.
protocol CancelSessionEndNotificationUseCase: Sendable {
    func callAsFunction(sessionId: UUID) async
}

final class CancelSessionEndNotificationUseCaseImpl: CancelSessionEndNotificationUseCase, @unchecked Sendable {
    private let repository: LocalNotificationRepository

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "CancelSessionEndNotificationUC"
    )

    init(repository: LocalNotificationRepository) {
        self.repository = repository
    }

    func callAsFunction(sessionId: UUID) async {
        let identifier = "session.end.\(sessionId.uuidString)"
        repository.removePendingNotificationRequests(withIdentifiers: [identifier])
        Self.log.info("NTF-01 cancelled id=\(identifier, privacy: .public)")
    }
}
