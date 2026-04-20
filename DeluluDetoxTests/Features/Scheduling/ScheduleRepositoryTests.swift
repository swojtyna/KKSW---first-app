import Combine
import XCTest
@testable import DeluluDetox

/// Plan 05-02 — real assertions replacing Plan 05-01 XCTSkipIf stubs.
/// Mirrors `SessionRepositoryTests` shape (temp-directory URL-provider seam,
/// 4-closure init). Exercises atomic JSON persistence + the multi-marker
/// consume path introduced for the cross-midnight defect (RESEARCH OQ#4).
@MainActor
final class ScheduleRepositoryTests: XCTestCase {

    private var tempDir: URL!
    private var schedulesURL: URL!
    private var eventsURL: URL!
    private var markerDirURL: URL!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        schedulesURL = tempDir.appendingPathComponent("schedule.json")
        eventsURL = tempDir.appendingPathComponent("schedule_events.json")
        markerDirURL = tempDir
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        cancellables.removeAll()
        try await super.tearDown()
    }

    private func makeRepo() -> ScheduleRepositoryImpl {
        ScheduleRepositoryImpl(
            schedulesURLProvider: { [schedulesURL] in schedulesURL! },
            eventsURLProvider: { [eventsURL] in eventsURL! },
            markerDirectoryURLProvider: { [markerDirURL] in markerDirURL! },
            appVersion: "test"
        )
    }

    private func makeSchedule(
        id: UUID = UUID(),
        enabled: Bool = true,
        endHour: Int = 17
    ) -> Schedule {
        Schedule(
            id: id,
            name: "Work block",
            daysOfWeek: [2, 3, 4, 5, 6],
            startHour: 9,
            startMinute: 0,
            endHour: endHour,
            endMinute: 0,
            enabled: enabled,
            blocklistId: UUID(),
            appVersion: "test"
        )
    }

    // MARK: - Codable round trip

    func testCodableRoundTrip() throws {
        let schedule = Schedule(
            id: UUID(),
            name: "Sleep block",
            daysOfWeek: [1, 7],
            startHour: 22,
            startMinute: 30,
            endHour: 6,
            endMinute: 15,
            enabled: true,
            blocklistId: UUID(),
            appVersion: "1.2.3"
        )

        let encoded = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(Schedule.self, from: encoded)

        XCTAssertEqual(decoded, schedule)
        XCTAssertTrue(decoded.crossesMidnight)
    }

    // MARK: - Atomic write + read-back via URL-provider seam

    func testAtomicWriteAndReadBackViaURLProviderSeam() async throws {
        let repo = makeRepo()
        let schedule = makeSchedule()

        try await repo.upsert(schedule)

        // File exists at the seam URL.
        XCTAssertTrue(FileManager.default.fileExists(atPath: schedulesURL.path))

        // Raw bytes decode back to the same payload.
        let data = try Data(contentsOf: schedulesURL)
        let decoded = try JSONDecoder().decode([Schedule].self, from: data)
        XCTAssertEqual(decoded, [schedule])
    }

    // MARK: - Publisher emits on upsert

    func testUpsertAddsNewScheduleToPublisher() async throws {
        let repo = makeRepo()
        let schedule = makeSchedule()

        // Initial publisher state is empty (CurrentValueSubject seeded at init).
        XCTAssertEqual(currentSchedules(from: repo), [])

        try await repo.upsert(schedule)
        XCTAssertEqual(currentSchedules(from: repo), [schedule])

        // Second upsert with same id REPLACES, not duplicates.
        var updated = schedule
        updated.enabled = false
        try await repo.upsert(updated)
        let afterSecond = currentSchedules(from: repo)
        XCTAssertEqual(afterSecond.count, 1)
        XCTAssertEqual(afterSecond.first?.id, schedule.id)
        XCTAssertEqual(afterSecond.first?.enabled, false)
    }

    /// Synchronous publisher read — mirrors SessionRepositoryTests shape.
    private func currentSchedules(
        from repo: ScheduleRepositoryImpl,
        timeout: TimeInterval = 1.0
    ) -> [Schedule] {
        var captured: [Schedule] = []
        var didReceive = false
        let exp = XCTestExpectation(description: "schedules value")
        let c = repo.schedulesPublisher.sink { value in
            captured = value
            if !didReceive {
                didReceive = true
                exp.fulfill()
            }
        }
        _ = XCTWaiter.wait(for: [exp], timeout: timeout)
        c.cancel()
        return captured
    }

    // MARK: - appendEvent

    func testAppendEventAppendsToSchedulesEventsJSON() async throws {
        let repo = makeRepo()
        let scheduleId = UUID()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = Date(timeIntervalSince1970: 1_700_000_600)

        try await repo.appendEvent(ScheduleEvent(scheduleId: scheduleId, kind: .started, timestamp: t0))
        try await repo.appendEvent(ScheduleEvent(scheduleId: scheduleId, kind: .ended, timestamp: t1))

        let data = try Data(contentsOf: eventsURL)
        let events = try JSONDecoder().decode([ScheduleEvent].self, from: data)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].kind, .started)
        XCTAssertEqual(events[0].timestamp, t0)
        XCTAssertEqual(events[1].kind, .ended)
        XCTAssertEqual(events[1].timestamp, t1)
    }

    // MARK: - consumeEventMarkers (RESEARCH OQ#4)

    func testConsumeEventMarkerReturnsAllMarkersAndDeletes() async throws {
        let repo = makeRepo()
        let scheduleId = UUID()

        // Write 3 marker files with OUT-OF-ORDER unix-millis suffixes (100, 200, 50).
        // Correct behavior: consume returns them sorted ascending [50, 100, 200].
        // Embed the timestamp inside the payload to match the filename suffix
        // exactly (avoid Double → Int64 rounding drift in the test's own check).
        func date(forMillis ms: Int64) -> Date {
            Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        }
        let markerMillis: [Int64] = [100, 200, 50]
        for ms in markerMillis {
            let url = markerDirURL.appendingPathComponent("\(SchedulePaths.markerFilePrefix)\(ms)\(SchedulePaths.markerFileSuffix)")
            let marker = ScheduleEventMarker(
                scheduleId: scheduleId,
                kind: ms == 200 ? .ended : .started,
                timestamp: date(forMillis: ms)
            )
            let data = try JSONEncoder().encode(marker)
            try data.write(to: url, options: [.atomic])
        }

        // Also drop an unrelated file to confirm isMarkerFile filter.
        try "noise".data(using: .utf8)!.write(to: markerDirURL.appendingPathComponent("other.json"))

        let consumed = try await repo.consumeEventMarkers()
        XCTAssertEqual(consumed.count, 3)
        // Verify ascending chronological order (filename suffixes [50, 100, 200]).
        // Compare pairwise to sidestep Double→Int64 rounding (0.050s is not
        // representable exactly; the returned Date may round to 49ms).
        XCTAssertLessThan(consumed[0].timestamp, consumed[1].timestamp)
        XCTAssertLessThan(consumed[1].timestamp, consumed[2].timestamp)
        // The "200 = .ended" marker lands last.
        XCTAssertEqual(consumed[2].kind, .ended)
        XCTAssertEqual(consumed[0].kind, .started)
        XCTAssertEqual(consumed[1].kind, .started)

        // All 3 marker files removed; the unrelated file remains.
        let remaining = try FileManager.default.contentsOfDirectory(atPath: markerDirURL.path)
        XCTAssertFalse(remaining.contains { $0.hasPrefix(SchedulePaths.markerFilePrefix) })
        XCTAssertTrue(remaining.contains("other.json"))
    }

}
