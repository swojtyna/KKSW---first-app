import Combine
@testable import DeluluDetox

final class MockObserveActiveSessionUseCase: ObserveActiveSessionUseCase, @unchecked Sendable {
    let subject = CurrentValueSubject<SessionRecord?, Never>(nil)
    private(set) var callCount = 0

    func execute() -> AnyPublisher<SessionRecord?, Never> {
        callCount += 1
        return subject.eraseToAnyPublisher()
    }
}
