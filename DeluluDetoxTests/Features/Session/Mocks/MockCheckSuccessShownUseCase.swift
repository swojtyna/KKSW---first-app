import Foundation
@testable import DeluluDetox

final class MockCheckSuccessShownUseCase: CheckSuccessShownUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastSessionId: UUID?
    /// Test-configured: ids that return true when queried. Default: empty (everything returns false).
    var stubbedShownIds: Set<UUID> = []

    func execute(sessionId: UUID) -> Bool {
        callCount += 1
        lastSessionId = sessionId
        return stubbedShownIds.contains(sessionId)
    }
}
