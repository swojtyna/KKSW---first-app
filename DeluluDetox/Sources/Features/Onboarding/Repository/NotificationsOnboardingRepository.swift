import Combine
import Foundation

protocol NotificationsOnboardingRepository: Sendable {
    var completionPublisher: AnyPublisher<Void, Never> { get }
    func markCompleted()
}

final class NotificationsOnboardingRepositoryImpl: NotificationsOnboardingRepository, @unchecked Sendable {
    private let subject = PassthroughSubject<Void, Never>()
    var completionPublisher: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }
    func markCompleted() { subject.send() }
}
