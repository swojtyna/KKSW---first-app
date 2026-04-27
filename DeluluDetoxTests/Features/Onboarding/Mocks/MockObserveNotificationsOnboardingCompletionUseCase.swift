import Combine
import Foundation
@testable import DeluluDetox

final class MockObserveNotificationsOnboardingCompletionUseCase: ObserveNotificationsOnboardingCompletionUseCase, @unchecked Sendable {
    let subject = PassthroughSubject<Void, Never>()
    func execute() -> AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }
}
