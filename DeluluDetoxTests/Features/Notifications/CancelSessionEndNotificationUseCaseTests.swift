import Foundation
import UserNotifications
import Testing
@testable import DeluluDetox

@Suite("CancelSessionEndNotificationUseCase")
@MainActor
struct CancelSessionEndNotificationUseCaseTests {

    @Test("removes notification by session identifier")
    func removesByIdentifier() async {
        let repo = MockLocalNotificationRepository()
        let sut = CancelSessionEndNotificationUseCaseImpl(repository: repo)
        let sessionId = UUID()

        await sut(sessionId: sessionId)

        #expect(repo.removedIdentifierSets == [["session.end.\(sessionId.uuidString)"]])
    }

    @Test("is idempotent when no pending notification matches")
    func isIdempotentWhenNoPendingMatch() async {
        let repo = MockLocalNotificationRepository()
        repo.stubPending = []
        let sut = CancelSessionEndNotificationUseCaseImpl(repository: repo)

        await sut(sessionId: UUID())

        #expect(repo.removedIdentifierSets.count == 1)
    }
}
