import SwiftUINavigation

extension SessionStartViewModel {

    @CasePathable
    enum Destination: Equatable {
        /// User tapped Start while another session is already active — parent should
        /// route to the countdown screen instead of starting a new session.
        case sessionInProgress(SessionRecord)

        /// StartSessionUseCase returned successfully. Parent pushes the countdown
        /// screen constructed from this record.
        case countdownHandoff(SessionRecord)

        /// Error path — sarcastic-playful Polish copy (CONTEXT §D-12).
        case errorAlert(String)
    }

    // MARK: - Navigation intents

    func clearDestination() {
        destination = nil
    }
}
