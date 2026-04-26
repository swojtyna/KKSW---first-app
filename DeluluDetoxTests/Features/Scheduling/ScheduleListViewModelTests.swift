import Combine
import Foundation
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class ScheduleListViewModelTests {

    let mockObserve: MockObserveScheduleUseCase
    let mockToggle: MockToggleScheduleUseCase
    let mockCreateOrUpdate: MockCreateOrUpdateScheduleUseCase
    let mockObserveBlocklist: MockObserveBlocklistUseCase

    init() {
        DIContainer.shared.reset()

        mockObserve = MockObserveScheduleUseCase()
        mockToggle = MockToggleScheduleUseCase()
        mockCreateOrUpdate = MockCreateOrUpdateScheduleUseCase()
        mockObserveBlocklist = MockObserveBlocklistUseCase()

        DIContainer.shared.register(ObserveScheduleUseCase.self, scope: .unique) { [mockObserve] _ in mockObserve }
        DIContainer.shared.register(ToggleScheduleUseCase.self, scope: .unique) { [mockToggle] _ in mockToggle }
        DIContainer.shared.register(CreateOrUpdateScheduleUseCase.self, scope: .unique) { [mockCreateOrUpdate] _ in mockCreateOrUpdate }
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { [mockObserveBlocklist] _ in mockObserveBlocklist }
    }

    @Test("list observes schedule repository publisher")
    func listObservesScheduleRepositoryPublisher() async {
        let vm = ScheduleListViewModel()
        await yield()

        let seeded = [makeSchedule()]
        mockObserve.subject.send(seeded)
        await yield()

        #expect(vm.schedules.count == 1)
        #expect(vm.schedules.first?.id == seeded.first?.id)
    }

    @Test("tapEditExisting sets editor destination with schedule")
    func tapEditExistingSetsEditorDestinationWithSchedule() async {
        let vm = ScheduleListViewModel()
        let schedule = makeSchedule(days: [1, 7])

        vm.editTapped(schedule)

        guard case .scheduleEditor(let editorVM) = vm.destination else {
            Issue.record("Expected .scheduleEditor destination, got \(String(describing: vm.destination))")
            return
        }
        #expect(editorVM.daysOfWeek == Set(schedule.daysOfWeek))
        #expect(editorVM.startHour == schedule.startHour)
        #expect(editorVM.endHour == schedule.endHour)
        #expect(editorVM.enabled == schedule.enabled)
    }

    @Test("tapCreateNew sets editor destination with nil")
    func tapCreateNewSetsEditorDestinationWithNil() async {
        let vm = ScheduleListViewModel()

        vm.createTapped()

        guard case .scheduleEditor(let editorVM) = vm.destination else {
            Issue.record("Expected .scheduleEditor destination, got \(String(describing: vm.destination))")
            return
        }
        #expect(editorVM.daysOfWeek.isEmpty)
        #expect(editorVM.startHour == 9)
        #expect(editorVM.endHour == 17)
    }

    @Test("toggleRow calls toggle schedule use case")
    func toggleRowCallsToggleScheduleUseCase() async {
        let vm = ScheduleListViewModel()
        let id = UUID()

        await vm.toggleSchedule(scheduleId: id, enabled: false)

        #expect(mockToggle.callCount == 1)
        #expect(mockToggle.lastInputScheduleId == id)
        #expect(mockToggle.lastInputEnabled == false)
    }
}

// MARK: - Private Helpers

private extension ScheduleListViewModelTests {
    func yield() async {
        await Task.yield()
        await Task.yield()
    }

    func makeSchedule(
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
}
