import XCTest
import UserNotifications
@testable import DeluluDetox

@MainActor
final class CancelSessionEndNotificationUseCaseTests: XCTestCase {

    func testRemovesByIdentifier() async {
        let repo = MockLocalNotificationRepository()
        let sut = CancelSessionEndNotificationUseCaseImpl(repository: repo)
        let sessionId = UUID()

        await sut(sessionId: sessionId)

        XCTAssertEqual(repo.removedIdentifierSets, [["session.end.\(sessionId.uuidString)"]])
    }

    func testIsIdempotent_whenNoPendingMatch() async {
        let repo = MockLocalNotificationRepository()
        repo.stubPending = [] // nothing to remove
        let sut = CancelSessionEndNotificationUseCaseImpl(repository: repo)

        await sut(sessionId: UUID())

        // UN API is a no-op on unknown ids; we still record the attempt.
        XCTAssertEqual(repo.removedIdentifierSets.count, 1)
    }
}
