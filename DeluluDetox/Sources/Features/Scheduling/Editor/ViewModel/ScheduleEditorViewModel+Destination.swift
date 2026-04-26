import SwiftUINavigation

extension ScheduleEditorViewModel {

    @CasePathable
    enum Destination: Equatable {
        /// Sarcastic Polish error toast — CONTEXT §D-14.
        case errorAlert(String)
    }

    // MARK: - Navigation intents

    func clearDestination() {
        destination = nil
    }
}
