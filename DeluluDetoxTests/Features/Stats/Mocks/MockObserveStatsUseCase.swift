import Combine
import Foundation
@testable import DeluluDetox

/// Test double for `ObserveStatsUseCase`. Emits `subject.value` as the
/// observable `Stats`. Tests drive emissions via `subject.send(...)`.
final class MockObserveStatsUseCase: ObserveStatsUseCase, @unchecked Sendable {
    let subject = CurrentValueSubject<Stats, Never>(.empty)

    func execute() -> AnyPublisher<Stats, Never> {
        subject.eraseToAnyPublisher()
    }
}
