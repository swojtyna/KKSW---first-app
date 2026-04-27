import Combine
import FamilyControls

protocol ObserveScreenTimeAuthStatusUseCase: Sendable {
    func execute() -> AnyPublisher<AuthorizationStatus, Never>
}

final class ObserveScreenTimeAuthStatusUseCaseImpl: ObserveScreenTimeAuthStatusUseCase {
    private let repository: ScreenTimeAuthRepository

    init(repository: ScreenTimeAuthRepository) {
        self.repository = repository
    }

    func execute() -> AnyPublisher<AuthorizationStatus, Never> {
        repository.statusPublisher
    }
}
