import Foundation
import Testing
@testable import DeluluDetox

@Suite("CreateOrUpdateScheduleUseCase")
struct CreateOrUpdateScheduleUseCaseTests {

    @Test("create persists schedule with new UUID")
    func createAssignsNewUUIDAndPersists() async throws {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = CreateOrUpdateScheduleUseCaseImpl(repository: repo, sync: sync)
        let schedule = makeSchedule()

        try await uc.execute(schedule)

        #expect(repo.upsertCallCount == 1)
        #expect(repo.lastUpserted?.id == schedule.id)
        #expect(repo.schedulesSubject.value == [schedule])
    }

    @Test("update preserves existing id")
    func updatePreservesExistingId() async throws {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = CreateOrUpdateScheduleUseCaseImpl(repository: repo, sync: sync)

        let id = UUID()
        let first = makeSchedule(id: id, endHour: 17)
        try await uc.execute(first)

        var second = first
        second.endHour = 18
        try await uc.execute(second)

        #expect(repo.upsertCallCount == 2)
        #expect(repo.lastUpserted?.id == id)
        #expect(repo.lastUpserted?.endHour == 18)
        #expect(repo.schedulesSubject.value.count == 1)
    }

    @Test("triggers sync after upsert")
    func triggersSyncAfterUpsert() async throws {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = CreateOrUpdateScheduleUseCaseImpl(repository: repo, sync: sync)
        let schedule = makeSchedule()

        try await uc.execute(schedule)

        #expect(sync.callCount == 1)
        #expect(sync.lastInputSchedule?.id == schedule.id)
        #expect(repo.upsertCallCount == 1)
    }
}

// MARK: - Private Helpers

private extension CreateOrUpdateScheduleUseCaseTests {
    func makeSchedule(id: UUID = UUID(), endHour: Int = 17) -> Schedule {
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
}
