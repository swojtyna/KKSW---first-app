import FamilyControls
@testable import DeluluDetox

final class MockScreenTimeAuthRepository: ScreenTimeAuthRepository {
    var stubbedStatus: AuthorizationStatus = .notDetermined
    var requestAuthorizationError: Error?
    var requestAuthorizationCallCount = 0

    var authorizationStatus: AuthorizationStatus {
        stubbedStatus
    }

    func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1
        if let error = requestAuthorizationError {
            throw error
        }
        stubbedStatus = .approved
    }
}
