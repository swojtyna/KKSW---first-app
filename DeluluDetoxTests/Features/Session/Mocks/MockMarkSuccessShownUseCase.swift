import Foundation
@testable import DeluluDetox

final class MockMarkSuccessShownUseCase: MarkSuccessShownUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastSessionId: UUID?
    private(set) var allMarked: Set<UUID> = []

    func callAsFunction(sessionId: UUID) {
        callCount += 1
        lastSessionId = sessionId
        allMarked.insert(sessionId)
    }
}
