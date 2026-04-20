import Foundation
@testable import DeluluDetox

final class MockCancelSessionEndNotificationUseCase: CancelSessionEndNotificationUseCase, @unchecked Sendable {
    private(set) var cancelledSessionIds: [UUID] = []

    func callAsFunction(sessionId: UUID) async {
        cancelledSessionIds.append(sessionId)
    }
}
