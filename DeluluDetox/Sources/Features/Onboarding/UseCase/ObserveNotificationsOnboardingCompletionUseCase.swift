import Combine
import Foundation

protocol ObserveNotificationsOnboardingCompletionUseCase: Sendable {
    func callAsFunction() -> AnyPublisher<Void, Never>
}

struct ObserveNotificationsOnboardingCompletionUseCaseImpl: ObserveNotificationsOnboardingCompletionUseCase {
    let repository: NotificationsOnboardingRepository
    func callAsFunction() -> AnyPublisher<Void, Never> { repository.completionPublisher }
}
