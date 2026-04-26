import Foundation
import Combine
import Testing
@testable import DeluluDetox

@Suite("ScheduleRepository")
@MainActor
final class ScheduleRepositoryTests {

    let tempDir: URL
    let schedulesURL: URL
    let eventsURL: URL
    let markerDirURL: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        schedulesURL = tempDir.appendingPathComponent("schedule.json")
        eventsURL = tempDir.appendingPathComponent("schedule_events.json")
        markerDirURL = tempDir
    }

    deinit {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Codable round trip

    @Test("Codable round trip")
    func codableRoundTrip() throws {
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

        #expect(decoded == schedule)
        #expect(decoded.crossesMidnight)
    }

    // MARK: - Atomic write + read-back via URL-provider seam

    @Test("atomic write and read-back via URL-provider seam")
    func atomicWriteAndReadBackViaURLProviderSeam() async throws {
        let repo = makeRepo()
        let schedule = makeSchedule()

        try await repo.upsert(schedule)

        #expect(FileManager.default.fileExists(atPath: schedulesURL.path))

        let data = try Data(contentsOf: schedulesURL)
        let decoded = try JSONDecoder().decode([Schedule].self, from: data)
        #expect(decoded == [schedule])
    }

    // MARK: - Publisher emits on upsert

    @Test("upsert adds new schedule to publisher and replaces on second upsert")
    func upsertAddsNewScheduleToPublisher() async throws {
        let repo = makeRepo()
        let schedule = makeSchedule()

        #expect(currentSchedules(from: repo) == [])

        try await repo.upsert(schedule)
        #expect(currentSchedules(from: repo) == [schedule])

        var updated = schedule
        updated.enabled = false
        try await repo.upsert(updated)
        let afterSecond = currentSchedules(from: repo)
        #expect(afterSecond.count == 1)
        #expect(afterSecond.first?.id == schedule.id)
        #expect(afterSecond.first?.enabled == false)
    }

    // MARK: - appendEvent

    @Test("appendEvent appends to schedule_events.json")
    func appendEventAppendsToSchedulesEventsJSON() async throws {
        let repo = makeRepo()
        let scheduleId = UUID()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = Date(timeIntervalSince1970: 1_700_000_600)

        try await repo.appendEvent(ScheduleEvent(scheduleId: scheduleId, kind: .started, timestamp: t0))
        try await repo.appendEvent(ScheduleEvent(scheduleId: scheduleId, kind: .ended, timestamp: t1))

        let data = try Data(contentsOf: eventsURL)
        let events = try JSONDecoder().decode([ScheduleEvent].self, from: data)
        #expect(events.count == 2)
        #expect(events[0].kind == .started)
        #expect(events[0].timestamp == t0)
        #expect(events[1].kind == .ended)
        #expect(events[1].timestamp == t1)
    }

    // MARK: - consumeEventMarkers (RESEARCH OQ#4)

    @Test("consumeEventMarkers returns all markers sorted and deletes them")
    func consumeEventMarkerReturnsAllMarkersAndDeletes() async throws {
        let repo = makeRepo()
        let scheduleId = UUID()

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
            try JSONEncoder().encode(marker).write(to: url, options: [.atomic])
        }

        try "noise".data(using: .utf8)!.write(to: markerDirURL.appendingPathComponent("other.json"))

        let consumed = try await repo.consumeEventMarkers()
        #expect(consumed.count == 3)
        #expect(consumed[0].timestamp < consumed[1].timestamp)
        #expect(consumed[1].timestamp < consumed[2].timestamp)
        #expect(consumed[2].kind == .ended)
        #expect(consumed[0].kind == .started)
        #expect(consumed[1].kind == .started)

        let remaining = try FileManager.default.contentsOfDirectory(atPath: markerDirURL.path)
        #expect(!remaining.contains { $0.hasPrefix(SchedulePaths.markerFilePrefix) })
        #expect(remaining.contains("other.json"))
    }
}

// MARK: - Private Helpers

private extension ScheduleRepositoryTests {
    func makeRepo() -> ScheduleRepositoryImpl {
        ScheduleRepositoryImpl(
            schedulesURLProvider: { [schedulesURL] in schedulesURL },
            eventsURLProvider: { [eventsURL] in eventsURL },
            markerDirectoryURLProvider: { [markerDirURL] in markerDirURL },
            appVersion: "test"
        )
    }

    func makeSchedule(
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

    func currentSchedules(from repo: ScheduleRepositoryImpl) -> [Schedule] {
        var captured: [Schedule] = []
        let c = repo.schedulesPublisher.sink { captured = $0 }
        c.cancel()
        return captured
    }
}
