import Combine
import FamilyControls

// MARK: - Protocol

protocol ScreenTimeAuthRepository: Sendable {
    var statusPublisher: AnyPublisher<AuthorizationStatus, Never> { get }

    // Transitional: kept for DependencyContainer synchronous wiring in Phase 1 VMs.
    // Removed in 01.1-04 when AppRootViewModel switches to ObserveScreenTimeAuthStatusUseCase.
    var authorizationStatus: AuthorizationStatus { get }

    func requestAuthorization() async throws
    func refreshStatus()
}

// MARK: - Implementation

final class ScreenTimeAuthRepositoryImpl: ScreenTimeAuthRepository, @unchecked Sendable {
    private let statusSubject: CurrentValueSubject<AuthorizationStatus, Never>

    var statusPublisher: AnyPublisher<AuthorizationStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    var authorizationStatus: AuthorizationStatus {
        AuthorizationCenter.shared.authorizationStatus
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
