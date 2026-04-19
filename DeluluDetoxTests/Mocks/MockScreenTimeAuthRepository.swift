import Combine
import FamilyControls
@testable import DeluluDetox

final class MockScreenTimeAuthRepository: ScreenTimeAuthRepository, @unchecked Sendable {
    var stubbedStatus: AuthorizationStatus = .notDetermined {
        didSet { statusSubject.send(stubbedStatus) }
    }
    var requestAuthorizationError: Error?
    var requestAuthorizationCallCount = 0
    var refreshStatusCallCount = 0

    private let statusSubject: CurrentValueSubject<AuthorizationStatus, Never>

    var statusPublisher: AnyPublisher<AuthorizationStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    var authorizationStatus: AuthorizationStatus {
        stubbedStatus
    }

    init() {
        self.statusSubject = CurrentValueSubject(.notDetermined)
    }

    /// Test helper — explicit status mutation (alternative to setting `stubbedStatus`).
    func set(status: AuthorizationStatus) {
        stubbedStatus = status
    }

    func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1
        if let error = requestAuthorizationError {
            throw error
        }
        stubbedStatus = .approved
    }

    func refreshStatus() {
        refreshStatusCallCount += 1
        statusSubject.send(stubbedStatus)
    }
}
