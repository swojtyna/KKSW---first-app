import FamilyControls

protocol RefreshScreenTimeAuthStatusUseCase: Sendable {
    func callAsFunction()
}

final class RefreshScreenTimeAuthStatusUseCaseImpl: RefreshScreenTimeAuthStatusUseCase {
    private let repository: ScreenTimeAuthRepository

    init(repository: ScreenTimeAuthRepository) {
        self.repository = repository
    }

    func callAsFunction() {
        repository.refreshStatus()
    }
}
