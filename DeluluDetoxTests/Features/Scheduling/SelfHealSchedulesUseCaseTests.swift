import Foundation
import Testing
@testable import DeluluDetox

@Suite(.serialized)
final class SelfHealSchedulesUseCaseTests {

    let repo: MockScheduleRepository
    let shield: MockScheduleShieldRepository
    let observeBlocklist: MockObserveBlocklistUseCase
    let compute: MockComputeScheduleWindowUseCase
    let defaults: UserDefaults
    let defaultsSuiteName: String
    let sut: SelfHealSchedulesUseCaseImpl
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let scheduleId: UUID
    let blocklistId: UUID

    init() {
        scheduleId = UUID()
        blocklistId = UUID()

        let suiteName = "test.schedule.state.\(UUID().uuidString)"
        defaultsSuiteName = suiteName
        defaults = UserDefaults(suiteName: suiteName)!
        SelfHealSchedulesUseCaseImpl.defaultsOverride = defaults

        repo = MockScheduleRepository()
        shield = MockScheduleShieldRepository()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let bl = Blocklist(
            id: blocklistId,
            name: "Test Blocklist",
            records: [TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: now)],
            lastSelection: .init(),
            updatedAt: now,
            needsRepair: false
        )
        observeBlocklist = MockObserveBlocklistUseCase(initial: bl)
        compute = MockComputeScheduleWindowUseCase()

        sut = SelfHealSchedulesUseCaseImpl(
            scheduleRepo: repo,
            shieldRepo: shield,
            observeBlocklist: observeBlocklist,
            compute: compute,
            calendar: Calendar(identifier: .gregorian)
        )
    }

    deinit {
        SelfHealSchedulesUseCaseImpl.defaultsOverride = nil
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    @Test("applies shield when should be active but store is clear")
    func appliesShieldWhenShouldBeActiveButStoreClear() async throws {
        repo.schedulesSubject.send([makeSchedule(id: scheduleId, enabled: true)])
        compute.stubbedResult = ScheduleWindow(state: .active(endsAt: now.addingTimeInterval(3600)), currentWeekday: 2)

        let operations = try await sut(now: now)

        #expect(operations == 1)
        #expect(shield.applyShieldCallCount == 1)
        #expect(shield.clearShieldCallCount == 0)
        #expect(shield.lastAppliedBlocklist?.id == blocklistId)
        #expect(defaults.bool(forKey: ComputeScheduleWindowUseCaseImpl.lastAppliedKey(scheduleId: scheduleId)))
    }

    @Test("clears shield when store dirty but should not be active")
    func clearsShieldWhenStoreDirtyButShouldNotBeActive() async throws {
        repo.schedulesSubject.send([makeSchedule(id: scheduleId, enabled: true)])
        compute.stubbedResult = ScheduleWindow(state: .inactive, currentWeekday: 2)
        defaults.set(true, forKey: ComputeScheduleWindowUseCaseImpl.lastAppliedKey(scheduleId: scheduleId))

        let operations = try await sut(now: now)

        #expect(operations == 1)
        #expect(shield.applyShieldCallCount == 0)
        #expect(shield.clearShieldCallCount == 1)
        #expect(!defaults.bool(forKey: ComputeScheduleWindowUseCaseImpl.lastAppliedKey(scheduleId: scheduleId)))
    }

    @Test("no-op when state already matches")
    func noOpWhenStateMatches() async throws {
        repo.schedulesSubject.send([makeSchedule(id: scheduleId, enabled: true)])
        compute.stubbedResult = ScheduleWindow(state: .active(endsAt: now.addingTimeInterval(3600)), currentWeekday: 2)
        defaults.set(true, forKey: ComputeScheduleWindowUseCaseImpl.lastAppliedKey(scheduleId: scheduleId))

        let operations = try await sut(now: now)

        #expect(operations == 0)
        #expect(shield.applyShieldCallCount == 0)
        #expect(shield.clearShieldCallCount == 0)
    }

    @Test("iterates over all enabled schedules, skips disabled")
    func iteratesOverAllEnabledSchedules() async throws {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        repo.schedulesSubject.send([
            makeSchedule(id: id1, enabled: true),
            makeSchedule(id: id2, enabled: true),
            makeSchedule(id: id3, enabled: false),
        ])
        compute.stubbedResult = ScheduleWindow(state: .active(endsAt: now.addingTimeInterval(3600)), currentWeekday: 2)

        let operations = try await sut(now: now)

        #expect(operations == 2, "disabled schedule must not trigger shield ops")
        #expect(shield.applyShieldCallCount == 2)
        #expect(compute.callCount == 2, "compute must only be called for enabled schedules")
    }
}

// MARK: - Private Helpers

private extension SelfHealSchedulesUseCaseTests {
    func makeSchedule(id: UUID, enabled: Bool) -> Schedule {
        Schedule(
            id: id,
            name: "Test",
            daysOfWeek: [2, 3, 4, 5, 6],
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            enabled: enabled,
            blocklistId: blocklistId,
            appVersion: "test"
        )
    }
}
