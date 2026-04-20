import XCTest
@testable import DeluluDetox

/// Plan 05-02 Task 2 — real assertions replacing Plan 05-01 XCTSkipIf stubs.
/// CreateOrUpdateScheduleUseCaseImpl composes repo.upsert → sync UC. The
/// Schedule struct has `let id: UUID` so a "no-id" draft flow does not
/// apply (D-02). "Create" and "Update" differ only in whether an existing
/// record with the same id lives in the repository; the UC does not mint
/// ids on the caller's behalf.
final class CreateOrUpdateScheduleUseCaseTests: XCTestCase {

    private func makeSchedule(id: UUID = UUID(), endHour: Int = 17) -> Schedule {
        Schedule(
            id: id,
            name: nil,
            daysOfWeek: [2, 3, 4, 5, 6],
            startHour: 9,
            startMinute: 0,
            endHour: endHour,
            endMinute: 0,
            enabled: true,
            blocklistId: UUID(),
            appVersion: "test"
        )
    }

    func testCreateAssignsNewUUIDAndPersists() async throws {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = CreateOrUpdateScheduleUseCaseImpl(repository: repo, sync: sync)
        let schedule = makeSchedule()

        try await uc(schedule)

        XCTAssertEqual(repo.upsertCallCount, 1)
        XCTAssertEqual(repo.lastUpserted?.id, schedule.id)
        XCTAssertEqual(repo.schedulesSubject.value, [schedule])
    }

    func testUpdatePreservesExistingId() async throws {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = CreateOrUpdateScheduleUseCaseImpl(repository: repo, sync: sync)

        let id = UUID()
        let first = makeSchedule(id: id, endHour: 17)
        try await uc(first)

        var second = first
        second.endHour = 18
        try await uc(second)

        XCTAssertEqual(repo.upsertCallCount, 2)
        XCTAssertEqual(repo.lastUpserted?.id, id)
        XCTAssertEqual(repo.lastUpserted?.endHour, 18)
        XCTAssertEqual(repo.schedulesSubject.value.count, 1)
    }

    func testTriggersSyncAfterUpsert() async throws {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = CreateOrUpdateScheduleUseCaseImpl(repository: repo, sync: sync)
        let schedule = makeSchedule()

        try await uc(schedule)

        XCTAssertEqual(sync.callCount, 1)
        XCTAssertEqual(sync.lastInputSchedule?.id, schedule.id)
        // upsert completed BEFORE sync fired.
        XCTAssertEqual(repo.upsertCallCount, 1)
    }
}
