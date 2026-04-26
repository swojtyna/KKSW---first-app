import Foundation

protocol CompleteNotificationsOnboardingUseCase: Sendable {
    func callAsFunction()
}

struct CompleteNotificationsOnboardingUseCaseImpl: CompleteNotificationsOnboardingUseCase {
    let repository: NotificationsOnboardingRepository
    func callAsFunction() { repository.markCompleted() }
}
