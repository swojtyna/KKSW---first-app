import XCTest
@testable import DeluluDetox

/// Plan 05-02 lands these assertions.
final class ConsumeScheduleEventMarkerUseCaseTests: XCTestCase {

    func testConsumeAppendsAllMarkersToEventsJSON() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: 3 timestamp-suffixed marker files on disk → UC appends 3 ScheduleEvent rows to schedule_events.json in chronological order.")
    }

    func testConsumeDeletesMarkerFilesAfterAppending() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: marker files are removed from disk AFTER successful append — subsequent run sees 0 markers, appends nothing.")
    }

    func testConsumeReturnsZeroWhenNoMarkers() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: empty App Group directory → UC returns 0, does not throw, makes zero writes.")
    }

    func testConsumeSortsMarkersByTimestampBeforeAppend() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: marker files with out-of-order unix-millis suffixes → events appended in chronological (ascending) timestamp order, not filesystem-listing order.")
    }
}
