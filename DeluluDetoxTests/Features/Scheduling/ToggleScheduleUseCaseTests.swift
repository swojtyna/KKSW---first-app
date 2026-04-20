import XCTest
@testable import DeluluDetox

/// Plan 05-04 Task 2 — `ToggleScheduleUseCaseImpl` assertions.
@MainActor
final class ToggleScheduleUseCaseTests: XCTestCase {

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

    func testToggleEnableCallsUpsertThenSync() async throws {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = ToggleScheduleUseCaseImpl(repository: repo, sync: sync)

        let s = schedule(id: UUID(), enabled: false)
        repo.schedulesSubject.send([s])

        try await uc(scheduleId: s.id, enabled: true)

        XCTAssertEqual(repo.upsertCallCount, 1)
        XCTAssertEqual(repo.lastUpserted?.id, s.id)
        XCTAssertEqual(repo.lastUpserted?.enabled, true)
        XCTAssertEqual(sync.callCount, 1)
        XCTAssertEqual(sync.lastInputSchedule?.id, s.id)
        XCTAssertEqual(sync.lastInputSchedule?.enabled, true)
    }

    func testToggleDisableCallsUpsertThenSyncWhichStopsMonitoring() async throws {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = ToggleScheduleUseCaseImpl(repository: repo, sync: sync)

        let s = schedule(id: UUID(), enabled: true)
        repo.schedulesSubject.send([s])

        try await uc(scheduleId: s.id, enabled: false)

        XCTAssertEqual(repo.lastUpserted?.enabled, false)
        XCTAssertEqual(sync.lastInputSchedule?.enabled, false)
    }

    func testToggleMissingScheduleThrowsNotFound() async {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = ToggleScheduleUseCaseImpl(repository: repo, sync: sync)

        // Empty repo — schedulesSubject holds [].
        do {
            try await uc(scheduleId: UUID(), enabled: true)
            XCTFail("Expected ScheduleUseCaseError.scheduleNotFound")
        } catch let error as ScheduleUseCaseError {
            XCTAssertEqual(error, .scheduleNotFound)
        } catch {
            XCTFail("Expected ScheduleUseCaseError.scheduleNotFound, got \(error)")
        }

        XCTAssertEqual(repo.upsertCallCount, 0)
        XCTAssertEqual(sync.callCount, 0)
    }
}

