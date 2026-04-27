import Combine
import Foundation

protocol ObserveNotificationsOnboardingCompletionUseCase: Sendable {
    func execute() -> AnyPublisher<Void, Never>
}

struct ObserveNotificationsOnboardingCompletionUseCaseImpl: ObserveNotificationsOnboardingCompletionUseCase {
    let repository: NotificationsOnboardingRepository
    func execute() -> AnyPublisher<Void, Never> { repository.completionPublisher }
}
