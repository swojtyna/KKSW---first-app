@testable import DeluluDetox

final class MockRefreshScreenTimeAuthStatusUseCase: RefreshScreenTimeAuthStatusUseCase, @unchecked Sendable {
    var callCount = 0

    func execute() {
        callCount += 1
    }
}
