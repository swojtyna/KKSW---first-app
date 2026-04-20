import XCTest
@testable import DeluluDetox

/// Plan 05-04 Task 2 — `SyncScheduleWithSystemUseCaseImpl` assertions.
/// Pattern mirrors `SessionRepositoryTests.currentActive/...` — drive the
/// MockScheduleRepository's CurrentValueSubject so the UC's snapshot read
/// resolves synchronously.
@MainActor
final class SyncScheduleWithSystemUseCaseTests: XCTestCase {

    // MARK: - Helpers

    private func schedule(id: UUID, enabled: Bool) -> Schedule {
        Schedule(
            id: id,
            name: nil,
            daysOfWeek: [2, 3, 4, 5, 6],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0,
            enabled: enabled,
            blocklistId: UUID(),
            appVersion: "test"
        )
    }

    // MARK: - Tests

    func testSyncStopsOldThenStartsNewWhenEnabled() async throws {
        let repo = MockScheduleRepository()
        let monitoring = MockScheduleActivityMonitoringRepository()
        let uc = SyncScheduleWithSystemUseCaseImpl(monitoring: monitoring, repository: repo)

        let s = schedule(id: UUID(), enabled: true)
        repo.schedulesSubject.send([s])

        try await uc(schedule: s)

        XCTAssertEqual(monitoring.stopMonitoringCallCount, 1)
        XCTAssertEqual(monitoring.stoppedScheduleIds.last, s.id)
        XCTAssertEqual(monitoring.startMonitoringCallCount, 1)
        XCTAssertEqual(monitoring.lastStartedSchedule?.id, s.id)
        // Call-order assertion — stop BEFORE start.
        XCTAssertEqual(monitoring.callLog.first, .stop(scheduleId: s.id))
        XCTAssertEqual(monitoring.callLog.last, .start(scheduleId: s.id))
    }

    func testSyncOnlyStopsWhenScheduleDisabled() async throws {
        let repo = MockScheduleRepository()
        let monitoring = MockScheduleActivityMonitoringRepository()
        let uc = SyncScheduleWithSystemUseCaseImpl(monitoring: monitoring, repository: repo)

        let s = schedule(id: UUID(), enabled: false)
        repo.schedulesSubject.send([s])

        try await uc(schedule: s)

        XCTAssertEqual(monitoring.stopMonitoringCallCount, 1)
        XCTAssertEqual(monitoring.startMonitoringCallCount, 0)
    }

    func testSyncRollsBackScheduleJSONWhenStartMonitoringThrows() async {
        let repo = MockScheduleRepository()
        let monitoring = MockScheduleActivityMonitoringRepository()
        let uc = SyncScheduleWithSystemUseCaseImpl(monitoring: monitoring, repository: repo)

        // Seed prior snapshot: "enabled=false" version persisted before.
        let id = UUID()
        let prior = schedule(id: id, enabled: false)
        repo.schedulesSubject.send([prior])

        // Caller passes the "new" enabled=true version.
        let new = schedule(id: id, enabled: true)

        struct BoomError: Error {}
        monitoring.startMonitoringError = ScheduleActivityMonitoringError.startFailed(BoomError())

        do {
            try await uc(schedule: new)
            XCTFail("Expected uc(schedule:) to throw when startMonitoring throws")
        } catch {
            // Expected — rethrows.
        }

        XCTAssertEqual(monitoring.stopMonitoringCallCount, 1)
        XCTAssertEqual(monitoring.startMonitoringCallCount, 1)
        // Rollback: upsert called with prior snapshot.
        XCTAssertEqual(repo.upsertCallCount, 1)
        XCTAssertEqual(repo.lastUpserted?.id, id)
        XCTAssertEqual(repo.lastUpserted?.enabled, false)
    }

    func testSyncDoesNotRetryStopMonitoringAfterStartFailure() async {
        let repo = MockScheduleRepository()
        let monitoring = MockScheduleActivityMonitoringRepository()
        let uc = SyncScheduleWithSystemUseCaseImpl(monitoring: monitoring, repository: repo)

        let s = schedule(id: UUID(), enabled: true)
        repo.schedulesSubject.send([s])

        struct BoomError: Error {}
        monitoring.startMonitoringError = ScheduleActivityMonitoringError.startFailed(BoomError())

        _ = try? await uc(schedule: s)

        // Exactly one stop (pre-start), never re-called after the start threw.
        XCTAssertEqual(monitoring.stopMonitoringCallCount, 1)
    }
}
