import Foundation
import Testing
@testable import DeluluDetox

@Suite("ToggleScheduleUseCase")
@MainActor
struct ToggleScheduleUseCaseTests {

    @Test("toggle enable calls upsert then sync")
    func toggleEnableCallsUpsertThenSync() async throws {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = ToggleScheduleUseCaseImpl(repository: repo, sync: sync)

        let s = makeSchedule(id: UUID(), enabled: false)
        repo.schedulesSubject.send([s])

        try await uc.execute(scheduleId: s.id, enabled: true)

        #expect(repo.upsertCallCount == 1)
        #expect(repo.lastUpserted?.id == s.id)
        #expect(repo.lastUpserted?.enabled == true)
        #expect(sync.callCount == 1)
        #expect(sync.lastInputSchedule?.id == s.id)
        #expect(sync.lastInputSchedule?.enabled == true)
    }

    @Test("toggle disable calls upsert then sync with enabled=false")
    func toggleDisableCallsUpsertThenSyncWhichStopsMonitoring() async throws {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = ToggleScheduleUseCaseImpl(repository: repo, sync: sync)

        let s = makeSchedule(id: UUID(), enabled: true)
        repo.schedulesSubject.send([s])

        try await uc.execute(scheduleId: s.id, enabled: false)

        #expect(repo.lastUpserted?.enabled == false)
        #expect(sync.lastInputSchedule?.enabled == false)
    }

    @Test("toggle missing schedule throws .scheduleNotFound")
    func toggleMissingScheduleThrowsNotFound() async {
        let repo = MockScheduleRepository()
        let sync = MockSyncScheduleWithSystemUseCase()
        let uc = ToggleScheduleUseCaseImpl(repository: repo, sync: sync)

        do {
            try await uc.execute(scheduleId: UUID(), enabled: true)
            Issue.record("Expected ScheduleUseCaseError.scheduleNotFound")
        } catch let error as ScheduleUseCaseError {
            #expect(error == .scheduleNotFound)
        } catch {
            Issue.record("Expected ScheduleUseCaseError.scheduleNotFound, got \(error)")
        }

        #expect(repo.upsertCallCount == 0)
        #expect(sync.callCount == 0)
    }
}

// MARK: - Private Helpers

private extension ToggleScheduleUseCaseTests {
    func makeSchedule(id: UUID, enabled: Bool) -> Schedule {
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
}
