import Combine
@preconcurrency import FamilyControls

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
        let initial = MainActor.assumeIsolated {
            AuthorizationCenter.shared.authorizationStatus
        }
        self.statusSubject = CurrentValueSubject(initial)
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        await MainActor.run {
            statusSubject.send(AuthorizationCenter.shared.authorizationStatus)
        }
    }

    func refreshStatus() {
        MainActor.assumeIsolated {
            statusSubject.send(AuthorizationCenter.shared.authorizationStatus)
        }
    }
}
