import Combine

protocol ObserveActiveSessionUseCase: Sendable {
    func execute() -> AnyPublisher<SessionRecord?, Never>
}

final class ObserveActiveSessionUseCaseImpl: ObserveActiveSessionUseCase {
    private let repository: SessionRepository

    init(repository: SessionRepository) {
        self.repository = repository
    }

    func execute() -> AnyPublisher<SessionRecord?, Never> {
        repository.activeSessionPublisher
    }
}
