import SwiftUINavigation

extension CountdownViewModel {

    @CasePathable
    enum Destination: Equatable {
        case confirmEarlyEnd(SessionRecord)
    }

    // MARK: - Navigation intents

    func earlyEndTapped() {
        destination = .confirmEarlyEnd(session)
    }

    func dismissConfirm() {
        destination = nil
    }
}
