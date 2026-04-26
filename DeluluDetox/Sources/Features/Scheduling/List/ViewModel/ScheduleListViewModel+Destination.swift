import SwiftUINavigation

extension ScheduleListViewModel {

    @CasePathable
    enum Destination: Equatable {
        case scheduleEditor(ScheduleEditorViewModel)
        case errorAlert(String)

        // ScheduleEditorViewModel is a reference type with no Equatable
        // conformance — use identity equality, same pattern as HomeViewModel.
        static func == (lhs: Destination, rhs: Destination) -> Bool {
            switch (lhs, rhs) {
            case (.scheduleEditor(let a), .scheduleEditor(let b)): return a === b
            case (.errorAlert(let a), .errorAlert(let b)): return a == b
            default: return false
            }
        }
    }

    // MARK: - Navigation intents

    func createTapped() {
        destination = .scheduleEditor(ScheduleEditorViewModel(existing: nil))
    }

    func editTapped(_ schedule: Schedule) {
        destination = .scheduleEditor(ScheduleEditorViewModel(existing: schedule))
    }

    func clearDestination() {
        destination = nil
    }
}
