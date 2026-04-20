import Combine
import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-07. ObserveScheduleUseCase wraps ScheduleRepository's
/// publisher — the mock exposes a subject so ScheduleListViewModelTests
/// can drive emissions independently of the repository.
final class MockObserveScheduleUseCase: ObserveScheduleUseCase, @unchecked Sendable {
    let subject = CurrentValueSubject<[Schedule], Never>([])
    var publisher: AnyPublisher<[Schedule], Never> { subject.eraseToAnyPublisher() }

    private(set) var callCount = 0
    func callAsFunction() -> AnyPublisher<[Schedule], Never> {
        callCount += 1
        return publisher
    }
}
