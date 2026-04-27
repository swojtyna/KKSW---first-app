import Foundation
import Testing
@testable import DeluluDetox

@Suite("ConsumeScheduleEventMarkerUseCase")
struct ConsumeScheduleEventMarkerUseCaseTests {

    @Test("appends all markers to events JSON")
    func consumeAppendsAllMarkersToEventsJSON() async throws {
        let repo = MockScheduleRepository()
        let uc = ConsumeScheduleEventMarkerUseCaseImpl(repository: repo)

        let m1 = makeMarker(ms: 100, kind: .started)
        let m2 = makeMarker(ms: 200, kind: .ended)
        let m3 = makeMarker(ms: 300, kind: .started)
        repo.stubbedConsumedMarkers = [m1, m2, m3]

        let count = try await uc.execute()

        #expect(count == 3)
        #expect(repo.appendedEvents.count == 3)
        #expect(repo.appendedEvents[0].scheduleId == m1.scheduleId)
        #expect(repo.appendedEvents[0].kind == .started)
        #expect(repo.appendedEvents[0].timestamp == m1.timestamp)
        #expect(repo.appendedEvents[1].kind == .ended)
        #expect(repo.appendedEvents[2].scheduleId == m3.scheduleId)
    }

    @Test("deletes marker files after appending, does not double-consume")
    func consumeDeletesMarkerFilesAfterAppending() async throws {
        let repo = MockScheduleRepository()
        let uc = ConsumeScheduleEventMarkerUseCaseImpl(repository: repo)

        repo.stubbedConsumedMarkers = [
            makeMarker(ms: 100),
            makeMarker(ms: 200),
            makeMarker(ms: 300),
        ]

        let first = try await uc.execute()
        #expect(first == 3)
        #expect(repo.consumeEventMarkersCallCount == 1)

        let second = try await uc.execute()
        #expect(second == 0)
        #expect(repo.consumeEventMarkersCallCount == 2)
        #expect(repo.appendedEvents.count == 3)
    }

    @Test("returns zero when no markers exist")
    func consumeReturnsZeroWhenNoMarkers() async throws {
        let repo = MockScheduleRepository()
        let uc = ConsumeScheduleEventMarkerUseCaseImpl(repository: repo)

        let count = try await uc.execute()
        #expect(count == 0)
        #expect(repo.appendedEvents.isEmpty)
        #expect(repo.appendEventCallCount == 0)
    }

    @Test("preserves ascending timestamp order from repository")
    func consumeSortsMarkersByTimestampBeforeAppend() async throws {
        let repo = MockScheduleRepository()
        let uc = ConsumeScheduleEventMarkerUseCaseImpl(repository: repo)

        let sorted = [
            makeMarker(ms: 50, kind: .started),
            makeMarker(ms: 100, kind: .ended),
            makeMarker(ms: 200, kind: .started),
        ]
        repo.stubbedConsumedMarkers = sorted

        _ = try await uc.execute()

        let appendedTimestamps = repo.appendedEvents.map(\.timestamp)
        let expectedTimestamps = sorted.map(\.timestamp)
        #expect(appendedTimestamps == expectedTimestamps)
    }
}

// MARK: - Private Helpers

private extension ConsumeScheduleEventMarkerUseCaseTests {
    func makeMarker(ms: Int64, kind: ScheduleEventMarker.Kind = .started) -> ScheduleEventMarker {
        ScheduleEventMarker(
            scheduleId: UUID(),
            kind: kind,
            timestamp: Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        )
    }
}
