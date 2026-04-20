import Combine
import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-01 scaffold. Method surface grows as Plan 05-02/03/04
/// expand the `ScheduleRepository` protocol in-place. Today the protocol
/// declares only `schedulesPublisher`; this mock conforms to it + exposes
/// call-counter scaffolding that Plan 05-02 tests will exercise.
final class MockScheduleRepository: ScheduleRepository, @unchecked Sendable {
    // MARK: Publisher (exposed subject so tests can drive emissions).
    let schedulesSubject = CurrentValueSubject<[Schedule], Never>([])

    var schedulesPublisher: AnyPublisher<[Schedule], Never> {
        schedulesSubject.eraseToAnyPublisher()
    }

    // MARK: upsert (Plan 05-02 wires to real protocol method).
    private(set) var upsertCallCount = 0
    private(set) var lastUpserted: Schedule?
    var upsertError: Error?

    func upsert(_ schedule: Schedule) async throws {
        upsertCallCount += 1
        lastUpserted = schedule
        if let upsertError { throw upsertError }
        var current = schedulesSubject.value
        if let idx = current.firstIndex(where: { $0.id == schedule.id }) {
            current[idx] = schedule
        } else {
            current.append(schedule)
        }
        schedulesSubject.send(current)
    }

    // MARK: remove (Plan 05-02).
    private(set) var removeCallCount = 0
    private(set) var lastRemovedId: UUID?
    var removeError: Error?

    func remove(scheduleId: UUID) async throws {
        removeCallCount += 1
        lastRemovedId = scheduleId
        if let removeError { throw removeError }
        var current = schedulesSubject.value
        current.removeAll { $0.id == scheduleId }
        schedulesSubject.send(current)
    }

    // MARK: appendEvent (Plan 05-02).
    private(set) var appendEventCallCount = 0
    private(set) var appendedEvents: [ScheduleEvent] = []
    var appendEventError: Error?

    func appendEvent(_ event: ScheduleEvent) async throws {
        appendEventCallCount += 1
        appendedEvents.append(event)
        if let appendEventError { throw appendEventError }
    }

    // MARK: consumeEventMarkers (Plan 05-02).
    private(set) var consumeEventMarkersCallCount = 0
    var stubbedConsumedMarkers: [ScheduleEventMarker] = []
    var consumeEventMarkersError: Error?

    func consumeEventMarkers() async throws -> [ScheduleEventMarker] {
        consumeEventMarkersCallCount += 1
        if let consumeEventMarkersError { throw consumeEventMarkersError }
        let value = stubbedConsumedMarkers
        stubbedConsumedMarkers = []
        return value
    }
}
