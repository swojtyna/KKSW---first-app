import Combine
import XCTest
@testable import DeluluDetox

/// Plan 05-06 Task 1 assertions — promoted from Plan 01 XCTSkipIf stubs.
@MainActor
final class ScheduleEditorViewModelTests: XCTestCase {

    struct TestError: Error {}

    // Seeded blocklist id the VM picks up from ObserveBlocklistUseCase on init.
    let seededBlocklistId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    var mockCreateOrUpdate: MockCreateOrUpdateScheduleUseCase!
    var mockObserveBlocklist: MockObserveBlocklistUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()

        mockCreateOrUpdate = MockCreateOrUpdateScheduleUseCase()
        mockObserveBlocklist = MockObserveBlocklistUseCase(
            initial: Blocklist.empty(id: seededBlocklistId)
        )

        DIContainer.shared.register(CreateOrUpdateScheduleUseCase.self, scope: .application) { [mockCreateOrUpdate] _ in
            mockCreateOrUpdate!
        }
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .application) { [mockObserveBlocklist] _ in
            mockObserveBlocklist!
        }
    }

    override func tearDown() async throws {
        DIContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateHasNoDaysAndDefault09To17Enabled() {
        let vm = ScheduleEditorViewModel()
        XCTAssertTrue(vm.daysOfWeek.isEmpty)
        XCTAssertEqual(vm.startHour, 9)
        XCTAssertEqual(vm.startMinute, 0)
        XCTAssertEqual(vm.endHour, 17)
        XCTAssertEqual(vm.endMinute, 0)
        XCTAssertTrue(vm.enabled)
        XCTAssertNil(vm.destination)
    }

    // MARK: - Init from existing

    func testInitFromExistingSeedsAllFields() {
        let existing = Schedule(
            id: UUID(),
            name: nil,
            daysOfWeek: [2, 3, 4],
            startHour: 22,
            startMinute: 30,
            endHour: 6,
            endMinute: 0,
            enabled: false,
            blocklistId: seededBlocklistId,
            appVersion: "test"
        )
        let vm = ScheduleEditorViewModel(existing: existing)
        XCTAssertEqual(vm.daysOfWeek, [2, 3, 4])
        XCTAssertEqual(vm.startHour, 22)
        XCTAssertEqual(vm.startMinute, 30)
        XCTAssertEqual(vm.endHour, 6)
        XCTAssertEqual(vm.endMinute, 0)
        XCTAssertFalse(vm.enabled)
    }

    // MARK: - Presets

    func testPresetDniRoboczeSetsMonToFriWeekdays() {
        let vm = ScheduleEditorViewModel()
        vm.applyPresetDniRobocze()
        XCTAssertEqual(vm.daysOfWeek, [2, 3, 4, 5, 6])
    }

    func testPresetWeekendSetsSatAndSun() {
        let vm = ScheduleEditorViewModel()
        vm.applyPresetWeekend()
        XCTAssertEqual(vm.daysOfWeek, [7, 1])
    }

    func testPresetCodziennieSetsAllSeven() {
        let vm = ScheduleEditorViewModel()
        vm.applyPresetCodziennie()
        XCTAssertEqual(vm.daysOfWeek, [1, 2, 3, 4, 5, 6, 7])
    }

    // MARK: - Cross-midnight detection

    func testCrossMidnightDetectionWhenEndLessThanStart() {
        let vm = ScheduleEditorViewModel()

        vm.startHour = 22
        vm.startMinute = 0
        vm.endHour = 6
        vm.endMinute = 0
        XCTAssertTrue(vm.isCrossMidnight)

        vm.startHour = 9
        vm.startMinute = 0
        vm.endHour = 17
        vm.endMinute = 0
        XCTAssertFalse(vm.isCrossMidnight)
    }

    // MARK: - Save success

    func testSaveTappedCallsCreateOrUpdateUseCase() async throws {
        let vm = ScheduleEditorViewModel()
        // `.receive(on: .main)` defers the CurrentValueSubject seed onto the
        // next runloop tick; sleep so the sink lands before we exercise save.
        try await Task.sleep(nanoseconds: 20_000_000) // 20 ms
        vm.daysOfWeek = [2, 3, 4, 5, 6]
        vm.startHour = 9
        vm.startMinute = 0
        vm.endHour = 17
        vm.endMinute = 0
        vm.enabled = true

        let didSave = await vm.saveTapped()

        XCTAssertTrue(didSave)
        XCTAssertEqual(mockCreateOrUpdate.callCount, 1)
        XCTAssertEqual(mockCreateOrUpdate.lastInputSchedule?.daysOfWeek, [2, 3, 4, 5, 6])
        XCTAssertEqual(mockCreateOrUpdate.lastInputSchedule?.blocklistId, seededBlocklistId)
        XCTAssertEqual(mockCreateOrUpdate.lastInputSchedule?.startHour, 9)
        XCTAssertEqual(mockCreateOrUpdate.lastInputSchedule?.endHour, 17)
        XCTAssertEqual(mockCreateOrUpdate.lastInputSchedule?.enabled, true)
        XCTAssertNil(vm.destination)
    }

    // MARK: - Save failure

    func testSaveTappedFailureSetsErrorAlertDestination() async throws {
        mockCreateOrUpdate.createOrUpdateError = TestError()

        let vm = ScheduleEditorViewModel()
        // Let the `.receive(on: .main)` seed land before invoking save.
        try await Task.sleep(nanoseconds: 20_000_000) // 20 ms
        vm.daysOfWeek = [1]

        let didSave = await vm.saveTapped()

        XCTAssertFalse(didSave)
        XCTAssertEqual(mockCreateOrUpdate.callCount, 1)
        if case .errorAlert(let msg) = vm.destination {
            XCTAssertEqual(msg, "iOS się zbuntował, spróbuj jeszcze raz.")
        } else {
            XCTFail("Expected destination == .errorAlert(String), got \(String(describing: vm.destination))")
        }
    }
}
