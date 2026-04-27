import FamilyControls

protocol RequestScreenTimeAuthUseCase: Sendable {
    func execute() async throws
}

final class RequestScreenTimeAuthUseCaseImpl: RequestScreenTimeAuthUseCase {
    private let repository: ScreenTimeAuthRepository

    init(repository: ScreenTimeAuthRepository) {
        self.repository = repository
    }

    func execute() async throws {
        try await repository.requestAuthorization()
    }
}
