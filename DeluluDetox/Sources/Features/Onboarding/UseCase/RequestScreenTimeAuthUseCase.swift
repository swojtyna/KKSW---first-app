import FamilyControls

protocol RequestScreenTimeAuthUseCase: Sendable {
    func callAsFunction() async throws
}

final class RequestScreenTimeAuthUseCaseImpl: RequestScreenTimeAuthUseCase {
    private let repository: ScreenTimeAuthRepository

    init(repository: ScreenTimeAuthRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws {
        try await repository.requestAuthorization()
    }
}
