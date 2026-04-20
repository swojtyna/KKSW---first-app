import XCTest
@testable import DeluluDetox

/// Plan 05-02 lands these assertions. XCTSkipIf stubs keep the suite green
/// while documenting the exact behavior downstream plans must verify.
final class ScheduleRepositoryTests: XCTestCase {

    func testCodableRoundTrip() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: encode Schedule with full D-02 schema (id, name, daysOfWeek, startHour/Minute, endHour/Minute, enabled, blocklistId, appVersion), decode, assert equal.")
    }

    func testAtomicWriteAndReadBackViaURLProviderSeam() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: inject URLProvider test seam returning tmp URL; repository.upsert writes atomically; read file bytes back, decode, assert payload matches last upsert.")
    }

    func testUpsertAddsNewScheduleToPublisher() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: repository.upsert emits new array via schedulesPublisher; subscriber sees [schedule] after first upsert and [updated] after second upsert with same id.")
    }

    func testAppendEventAppendsToSchedulesEventsJSON() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: appendEvent reads schedule_events.json (or creates it), appends ScheduleEvent, writes atomically; subsequent read returns prior history + new row.")
    }

    func testConsumeEventMarkerReturnsAllMarkersAndDeletes() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: list schedule_event_marker_*.json via markerDirectoryURL, decode each, sort by unix-millis suffix, return chronologically, delete each after append; empty directory → returns [].")
    }
}
