import Combine
import FamilyControls
@testable import DeluluDetox

final class MockObserveScreenTimeAuthStatusUseCase: ObserveScreenTimeAuthStatusUseCase, @unchecked Sendable {
    /// Publicly exposed subject — tests call `.send(...)` to emit new statuses.
    let subject: CurrentValueSubject<AuthorizationStatus, Never>
    var callCount = 0

    init(initialStatus: AuthorizationStatus = .notDetermined) {
        self.subject = CurrentValueSubject(initialStatus)
    }

    func callAsFunction() -> AnyPublisher<AuthorizationStatus, Never> {
        callCount += 1
        return subject.eraseToAnyPublisher()
    }
}
