import Foundation

protocol CompleteNotificationsOnboardingUseCase: Sendable {
    func execute()
}

struct CompleteNotificationsOnboardingUseCaseImpl: CompleteNotificationsOnboardingUseCase {
    let repository: NotificationsOnboardingRepository
    func execute() { repository.markCompleted() }
}
