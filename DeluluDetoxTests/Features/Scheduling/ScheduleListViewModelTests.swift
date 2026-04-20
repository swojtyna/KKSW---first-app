import Combine
import Foundation
import XCTest
@testable import DeluluDetox

/// Plan 05-07 promoted these stubs to real assertions.
@MainActor
final class ScheduleListViewModelTests: XCTestCase {

    var mockObserve: MockObserveScheduleUseCase!
    var mockToggle: MockToggleScheduleUseCase!
    // ScheduleListViewModel's child ScheduleEditorViewModel resolves these via @LazyInjected:
    var mockCreateOrUpdate: MockCreateOrUpdateScheduleUseCase!
    var mockObserveBlocklist: MockObserveBlocklistUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()

        mockObserve = MockObserveScheduleUseCase()
        mockToggle = MockToggleScheduleUseCase()
        mockCreateOrUpdate = MockCreateOrUpdateScheduleUseCase()
        mockObserveBlocklist = MockObserveBlocklistUseCase()

        DIContainer.shared.register(ObserveScheduleUseCase.self, scope: .unique) { [mockObserve] _ in mockObserve! }
        DIContainer.shared.register(ToggleScheduleUseCase.self, scope: .unique) { [mockToggle] _ in mockToggle! }
        DIContainer.shared.register(CreateOrUpdateScheduleUseCase.self, scope: .unique) { [mockCreateOrUpdate] _ in mockCreateOrUpdate! }
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { [mockObserveBlocklist] _ in mockObserveBlocklist! }
    }

    override func tearDown() async throws {
        DIContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func yield() async {
        await Task.yield()
        await Task.yield()
    }

    private func makeSchedule(
        id: UUID = UUID(),
        days: [Int] = [2, 3, 4, 5, 6],
        enabled: Bool = true
    ) -> Schedule {
        Schedule(
            id: id,
            name: nil,
            daysOfWeek: days,
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            enabled: enabled,
            blocklistId: UUID(),
            appVersion: "test"
        )
    }

    // MARK: - Tests

    func testListObservesScheduleRepositoryPublisher() async {
        let vm = ScheduleListViewModel()
        await yield()

        let seeded = [makeSchedule()]
        mockObserve.subject.send(seeded)
        await yield()

        XCTAssertEqual(vm.schedules.count, 1)
        XCTAssertEqual(vm.schedules.first?.id, seeded.first?.id)
    }

    func testTapEditExistingSetsEditorDestinationWithSchedule() async {
        let vm = ScheduleListViewModel()
        let schedule = makeSchedule(days: [1, 7])

        vm.editTapped(schedule)

        guard case .scheduleEditor(let editorVM) = vm.destination else {
            XCTFail("Expected .scheduleEditor destination, got \(String(describing: vm.destination))")
            return
        }
        // ScheduleEditorViewModel init(existing:) copies daysOfWeek into a Set.
        XCTAssertEqual(editorVM.daysOfWeek, Set(schedule.daysOfWeek))
        XCTAssertEqual(editorVM.startHour, schedule.startHour)
        XCTAssertEqual(editorVM.endHour, schedule.endHour)
        XCTAssertEqual(editorVM.enabled, schedule.enabled)
    }

    func testTapCreateNewSetsEditorDestinationWithNil() async {
        let vm = ScheduleListViewModel()

        vm.createTapped()

        guard case .scheduleEditor(let editorVM) = vm.destination else {
            XCTFail("Expected .scheduleEditor destination, got \(String(describing: vm.destination))")
            return
        }
        // Default init (existing = nil) → empty daysOfWeek, defaults 9-17, enabled true.
        XCTAssertTrue(editorVM.daysOfWeek.isEmpty)
        XCTAssertEqual(editorVM.startHour, 9)
        XCTAssertEqual(editorVM.endHour, 17)
    }

    func testToggleRowCallsToggleScheduleUseCase() async {
        let vm = ScheduleListViewModel()
        let id = UUID()

        await vm.toggleSchedule(scheduleId: id, enabled: false)

        XCTAssertEqual(mockToggle.callCount, 1)
        XCTAssertEqual(mockToggle.lastInputScheduleId, id)
        XCTAssertEqual(mockToggle.lastInputEnabled, false)
    }
}
