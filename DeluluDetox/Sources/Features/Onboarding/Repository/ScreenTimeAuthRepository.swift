import Combine
import FamilyControls

// MARK: - Protocol

protocol ScreenTimeAuthRepository: Sendable {
    var statusPublisher: AnyPublisher<AuthorizationStatus, Never> { get }
    func requestAuthorization() async throws
    func refreshStatus()
}

// MARK: - Implementation

final class ScreenTimeAuthRepositoryImpl: ScreenTimeAuthRepository, @unchecked Sendable {
    private let statusSubject: CurrentValueSubject<AuthorizationStatus, Never>

    var statusPublisher: AnyPublisher<AuthorizationStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    init() {
        self.statusSubject = CurrentValueSubject(AuthorizationCenter.shared.authorizationStatus)
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        statusSubject.send(AuthorizationCenter.shared.authorizationStatus)
    }

    func refreshStatus() {
        statusSubject.send(AuthorizationCenter.shared.authorizationStatus)
    }
}
