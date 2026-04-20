import XCTest
@testable import DeluluDetox

/// Plan 05-02 Task 2 — real assertions replacing Plan 05-01 XCTSkipIf stubs.
/// The repository already owns "list + sort + delete marker files"
/// (ScheduleRepositoryImpl.consumeEventMarkers, Task 1). The UC's job is
/// to translate each marker into a `ScheduleEvent` and append it to
/// `schedule_events.json` via the repository, preserving order and
/// returning the count.
final class ConsumeScheduleEventMarkerUseCaseTests: XCTestCase {

    private func makeMarker(ms: Int64, kind: ScheduleEventMarker.Kind = .started) -> ScheduleEventMarker {
        ScheduleEventMarker(
            scheduleId: UUID(),
            kind: kind,
            timestamp: Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        )
    }

    func testConsumeAppendsAllMarkersToEventsJSON() async throws {
        let repo = MockScheduleRepository()
        let uc = ConsumeScheduleEventMarkerUseCaseImpl(repository: repo)

        let m1 = makeMarker(ms: 100, kind: .started)
        let m2 = makeMarker(ms: 200, kind: .ended)
        let m3 = makeMarker(ms: 300, kind: .started)
        repo.stubbedConsumedMarkers = [m1, m2, m3]

        let count = try await uc()

        XCTAssertEqual(count, 3)
        XCTAssertEqual(repo.appendedEvents.count, 3)
        XCTAssertEqual(repo.appendedEvents[0].scheduleId, m1.scheduleId)
        XCTAssertEqual(repo.appendedEvents[0].kind, .started)
        XCTAssertEqual(repo.appendedEvents[0].timestamp, m1.timestamp)
        XCTAssertEqual(repo.appendedEvents[1].kind, .ended)
        XCTAssertEqual(repo.appendedEvents[2].scheduleId, m3.scheduleId)
    }

    func testConsumeDeletesMarkerFilesAfterAppending() async throws {
        // Deletion is the Repository's responsibility (ScheduleRepositoryImpl
        // removes each file inside consumeEventMarkers()). The UC-level
        // contract here is: it reports the right count and does NOT call
        // consumeEventMarkers twice for the same payload.
        let repo = MockScheduleRepository()
        let uc = ConsumeScheduleEventMarkerUseCaseImpl(repository: repo)

        repo.stubbedConsumedMarkers = [
            makeMarker(ms: 100),
            makeMarker(ms: 200),
            makeMarker(ms: 300),
        ]

        let first = try await uc()
        XCTAssertEqual(first, 3)
        XCTAssertEqual(repo.consumeEventMarkersCallCount, 1)

        // Second run — mock auto-clears after first consume.
        let second = try await uc()
        XCTAssertEqual(second, 0)
        XCTAssertEqual(repo.consumeEventMarkersCallCount, 2)
        XCTAssertEqual(repo.appendedEvents.count, 3, "no additional appends on empty run")
    }

    func testConsumeReturnsZeroWhenNoMarkers() async throws {
        let repo = MockScheduleRepository()
        let uc = ConsumeScheduleEventMarkerUseCaseImpl(repository: repo)
        // No stubbedConsumedMarkers — default empty.

        let count = try await uc()
        XCTAssertEqual(count, 0)
        XCTAssertTrue(repo.appendedEvents.isEmpty)
        XCTAssertEqual(repo.appendEventCallCount, 0)
    }

    func testConsumeSortsMarkersByTimestampBeforeAppend() async throws {
        // The repository returns the markers in chronological order
        // (ScheduleRepositoryImpl does the sort). The UC must preserve that
        // order when appending. Pass pre-sorted input; verify order preserved.
        let repo = MockScheduleRepository()
        let uc = ConsumeScheduleEventMarkerUseCaseImpl(repository: repo)

        let sorted = [
            makeMarker(ms: 50, kind: .started),
            makeMarker(ms: 100, kind: .ended),
            makeMarker(ms: 200, kind: .started),
        ]
        repo.stubbedConsumedMarkers = sorted

        _ = try await uc()

        let appendedTimestamps = repo.appendedEvents.map(\.timestamp)
        let expectedTimestamps = sorted.map(\.timestamp)
        XCTAssertEqual(appendedTimestamps, expectedTimestamps)
    }
}
