import Combine
import Foundation
@testable import DeluluDetox

final class MockObserveNotificationsOnboardingCompletionUseCase: ObserveNotificationsOnboardingCompletionUseCase, @unchecked Sendable {
    let subject = PassthroughSubject<Void, Never>()
    func callAsFunction() -> AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }
}
