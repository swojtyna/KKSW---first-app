import XCTest
@testable import DeluluDetox

/// Plan 05-04 Task 3 — real assertions for SelfHealSchedulesUseCase (CONTEXT §D-18).
final class SelfHealSchedulesUseCaseTests: XCTestCase {

    private var repo: MockScheduleRepository!
    private var shield: MockScheduleShieldRepository!
    private var observeBlocklist: MockObserveBlocklistUseCase!
    private var compute: MockComputeScheduleWindowUseCase!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var sut: SelfHealSchedulesUseCaseImpl!

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let scheduleId = UUID()
    private let blocklistId = UUID()

    override func setUpWithError() throws {
        try super.setUpWithError()
        repo = MockScheduleRepository()
        shield = MockScheduleShieldRepository()
        observeBlocklist = MockObserveBlocklistUseCase(initial: makeBlocklist())
        compute = MockComputeScheduleWindowUseCase()

        defaultsSuiteName = "test.schedule.state.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        XCTAssertNotNil(defaults)
        SelfHealSchedulesUseCaseImpl.defaultsOverride = defaults

        sut = SelfHealSchedulesUseCaseImpl(
            scheduleRepo: repo,
            shieldRepo: shield,
            observeBlocklist: observeBlocklist,
            compute: compute,
            calendar: Calendar(identifier: .gregorian)
        )
    }

    override func tearDownWithError() throws {
        SelfHealSchedulesUseCaseImpl.defaultsOverride = nil
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        sut = nil
        repo = nil
        shield = nil
        observeBlocklist = nil
        compute = nil
        defaults = nil
        defaultsSuiteName = nil
        try super.tearDownWithError()
    }

    func testAppliesShieldWhenShouldBeActiveButStoreClear() async throws {
        repo.schedulesSubject.send([makeSchedule(id: scheduleId, enabled: true)])
        compute.stubbedResult = ScheduleWindow(state: .active(endsAt: now.addingTimeInterval(3600)), currentWeekday: 2)

        let operations = try await sut(now: now)

        XCTAssertEqual(operations, 1)
        XCTAssertEqual(shield.applyShieldCallCount, 1)
        XCTAssertEqual(shield.clearShieldCallCount, 0)
        XCTAssertEqual(shield.lastAppliedBlocklist?.id, blocklistId)
        XCTAssertTrue(defaults.bool(forKey: ComputeScheduleWindowUseCaseImpl.lastAppliedKey(scheduleId: scheduleId)))
    }

    func testClearsShieldWhenStoreDirtyButShouldNotBeActive() async throws {
        repo.schedulesSubject.send([makeSchedule(id: scheduleId, enabled: true)])
        compute.stubbedResult = ScheduleWindow(state: .inactive, currentWeekday: 2)
        defaults.set(true, forKey: ComputeScheduleWindowUseCaseImpl.lastAppliedKey(scheduleId: scheduleId))

        let operations = try await sut(now: now)

        XCTAssertEqual(operations, 1)
        XCTAssertEqual(shield.applyShieldCallCount, 0)
        XCTAssertEqual(shield.clearShieldCallCount, 1)
        XCTAssertFalse(defaults.bool(forKey: ComputeScheduleWindowUseCaseImpl.lastAppliedKey(scheduleId: scheduleId)))
    }

    func testNoOpWhenStateMatches() async throws {
        repo.schedulesSubject.send([makeSchedule(id: scheduleId, enabled: true)])
        compute.stubbedResult = ScheduleWindow(state: .active(endsAt: now.addingTimeInterval(3600)), currentWeekday: 2)
        defaults.set(true, forKey: ComputeScheduleWindowUseCaseImpl.lastAppliedKey(scheduleId: scheduleId))

        let operations = try await sut(now: now)

        XCTAssertEqual(operations, 0)
        XCTAssertEqual(shield.applyShieldCallCount, 0)
        XCTAssertEqual(shield.clearShieldCallCount, 0)
    }

    func testIteratesOverAllEnabledSchedules() async throws {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID() // disabled — must be skipped
        repo.schedulesSubject.send([
            makeSchedule(id: id1, enabled: true),
            makeSchedule(id: id2, enabled: true),
            makeSchedule(id: id3, enabled: false),
        ])
        compute.stubbedResult = ScheduleWindow(state: .active(endsAt: now.addingTimeInterval(3600)), currentWeekday: 2)

        let operations = try await sut(now: now)

        XCTAssertEqual(operations, 2, "Disabled schedule must not trigger shield ops.")
        XCTAssertEqual(shield.applyShieldCallCount, 2)
        XCTAssertEqual(compute.callCount, 2, "Compute must only be called for enabled schedules.")
    }

    // MARK: - Helpers

    private func makeSchedule(id: UUID, enabled: Bool) -> Schedule {
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

    private func makeBlocklist() -> Blocklist {
        Blocklist(
            id: blocklistId,
            name: "Test Blocklist",
            records: [
                TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: now),
            ],
            lastSelection: .init(),
            updatedAt: now,
            needsRepair: false
        )
    }
}
