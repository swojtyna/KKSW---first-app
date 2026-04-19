@testable import DeluluDetox

final class MockRefreshScreenTimeAuthStatusUseCase: RefreshScreenTimeAuthStatusUseCase, @unchecked Sendable {
    var callCount = 0

    func callAsFunction() {
        callCount += 1
    }
}
