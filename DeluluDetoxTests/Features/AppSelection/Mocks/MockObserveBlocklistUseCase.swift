import Combine
@testable import DeluluDetox

final class MockObserveBlocklistUseCase: ObserveBlocklistUseCase, @unchecked Sendable {
    /// Publicly exposed subject — tests call `.send(...)` to emit new blocklists.
    let subject: CurrentValueSubject<Blocklist, Never>
    private(set) var callCount = 0

    init(initial: Blocklist = .empty()) {
        self.subject = CurrentValueSubject(initial)
    }

    func callAsFunction() -> AnyPublisher<Blocklist, Never> {
        callCount += 1
        return subject.eraseToAnyPublisher()
    }
}
