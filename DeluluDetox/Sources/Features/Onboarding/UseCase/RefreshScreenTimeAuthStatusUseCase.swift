import FamilyControls

protocol RefreshScreenTimeAuthStatusUseCase: Sendable {
    func execute()
}

final class RefreshScreenTimeAuthStatusUseCaseImpl: RefreshScreenTimeAuthStatusUseCase {
    private let repository: ScreenTimeAuthRepository

    init(repository: ScreenTimeAuthRepository) {
        self.repository = repository
    }

    func execute() {
        repository.refreshStatus()
    }
}
