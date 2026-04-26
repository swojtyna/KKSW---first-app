import Combine
import Foundation
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class ScheduleEditorViewModelTests {

    struct TestError: Error {}

    let seededBlocklistId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let mockCreateOrUpdate: MockCreateOrUpdateScheduleUseCase
    let mockObserveBlocklist: MockObserveBlocklistUseCase

    init() {
        DIContainer.shared.reset()

        mockCreateOrUpdate = MockCreateOrUpdateScheduleUseCase()
        let blocklistId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        mockObserveBlocklist = MockObserveBlocklistUseCase(
            initial: Blocklist.empty(id: blocklistId)
        )

        DIContainer.shared.register(CreateOrUpdateScheduleUseCase.self, scope: .application) { [mockCreateOrUpdate] _ in
            mockCreateOrUpdate
        }
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .application) { [mockObserveBlocklist] _ in
            mockObserveBlocklist
        }
    }

    // MARK: - Initial state

    @Test("initial state has no days and default 9–17 enabled")
    func initialStateHasNoDaysAndDefault09To17Enabled() {
        let vm = ScheduleEditorViewModel()
        #expect(vm.daysOfWeek.isEmpty)
        #expect(vm.startHour == 9)
        #expect(vm.startMinute == 0)
        #expect(vm.endHour == 17)
        #expect(vm.endMinute == 0)
        #expect(vm.enabled)
        #expect(vm.destination == nil)
    }

    // MARK: - Init from existing

    @Test("init from existing seeds all fields")
    func initFromExistingSeedsAllFields() {
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
        #expect(vm.daysOfWeek == [2, 3, 4])
        #expect(vm.startHour == 22)
        #expect(vm.startMinute == 30)
        #expect(vm.endHour == 6)
        #expect(vm.endMinute == 0)
        #expect(!vm.enabled)
    }

    // MARK: - Presets

    @Test("preset dni robocze sets Mon–Fri weekdays")
    func presetDniRoboczeSetsMonToFriWeekdays() {
        let vm = ScheduleEditorViewModel()
        vm.applyPresetDniRobocze()
        #expect(vm.daysOfWeek == [2, 3, 4, 5, 6])
    }

    @Test("preset weekend sets Sat and Sun")
    func presetWeekendSetsSatAndSun() {
        let vm = ScheduleEditorViewModel()
        vm.applyPresetWeekend()
        #expect(vm.daysOfWeek == [7, 1])
    }

    @Test("preset codziennie sets all seven")
    func presetCodziennieSetsAllSeven() {
        let vm = ScheduleEditorViewModel()
        vm.applyPresetCodziennie()
        #expect(vm.daysOfWeek == [1, 2, 3, 4, 5, 6, 7])
    }

    // MARK: - Cross-midnight detection

    @Test("cross-midnight detection when end less than start")
    func crossMidnightDetectionWhenEndLessThanStart() {
        let vm = ScheduleEditorViewModel()

        vm.startHour = 22
        vm.startMinute = 0
        vm.endHour = 6
        vm.endMinute = 0
        #expect(vm.isCrossMidnight)

        vm.startHour = 9
        vm.startMinute = 0
        vm.endHour = 17
        vm.endMinute = 0
        #expect(!vm.isCrossMidnight)
    }

    // MARK: - Save success

    @Test("saveTapped calls createOrUpdate use case")
    func saveTappedCallsCreateOrUpdateUseCase() async throws {
        let vm = ScheduleEditorViewModel()
        try await Task.sleep(nanoseconds: 20_000_000)
        vm.daysOfWeek = [2, 3, 4, 5, 6]
        vm.startHour = 9
        vm.startMinute = 0
        vm.endHour = 17
        vm.endMinute = 0
        vm.enabled = true

        let didSave = await vm.saveTapped()

        #expect(didSave)
        #expect(mockCreateOrUpdate.callCount == 1)
        #expect(mockCreateOrUpdate.lastInputSchedule?.daysOfWeek == [2, 3, 4, 5, 6])
        #expect(mockCreateOrUpdate.lastInputSchedule?.blocklistId == seededBlocklistId)
        #expect(mockCreateOrUpdate.lastInputSchedule?.startHour == 9)
        #expect(mockCreateOrUpdate.lastInputSchedule?.endHour == 17)
        #expect(mockCreateOrUpdate.lastInputSchedule?.enabled == true)
        #expect(vm.destination == nil)
    }

    // MARK: - Save failure

    @Test("saveTapped failure sets errorAlert destination")
    func saveTappedFailureSetsErrorAlertDestination() async throws {
        mockCreateOrUpdate.createOrUpdateError = TestError()

        let vm = ScheduleEditorViewModel()
        try await Task.sleep(nanoseconds: 20_000_000)
        vm.daysOfWeek = [1]

        let didSave = await vm.saveTapped()

        #expect(!didSave)
        #expect(mockCreateOrUpdate.callCount == 1)
        if case .errorAlert(let msg) = vm.destination {
            #expect(msg == "iOS się zbuntował, spróbuj jeszcze raz.")
        } else {
            Issue.record("Expected destination == .errorAlert(String), got \(String(describing: vm.destination))")
        }
    }
}
