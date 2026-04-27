import Combine
@testable import DeluluDetox

final class MockObserveSessionHistoryUseCase: ObserveSessionHistoryUseCase, @unchecked Sendable {
    let subject = CurrentValueSubject<[SessionRecord], Never>([])
    private(set) var callCount = 0

    func execute() -> AnyPublisher<[SessionRecord], Never> {
        callCount += 1
        return subject.eraseToAnyPublisher()
    }
}
