import Foundation
@testable import DeluluDetox

final class MockCancelSessionEndNotificationUseCase: CancelSessionEndNotificationUseCase, @unchecked Sendable {
    private(set) var cancelledSessionIds: [UUID] = []

    func execute(sessionId: UUID) async {
        cancelledSessionIds.append(sessionId)
    }
}
