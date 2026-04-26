@preconcurrency import FamilyControls
import Foundation
import SwiftUINavigation

extension HomeViewModel {

    @CasePathable
    enum Destination: Equatable {
        case picker(PickerSession)
        case errorAlert(String)
        case sessionStart(SessionStartViewModel)
        case countdown(CountdownViewModel)
        case sessionSuccess(SessionSuccessViewModel)
        case scheduleList(ScheduleListViewModel)
        case stats(StatsViewModel)

        // HomeViewModel.Destination cases containing non-Equatable payloads
        // (SessionStartViewModel / CountdownViewModel / SessionSuccessViewModel)
        // use identity equality here — rare in SwiftUINavigation usage; most
        // comparisons are case-path pattern matches, not Equatable ==.
        //
        // INTENT (`.stats` specifically): identity equality is BY DESIGN.
        // `statsCardTapped()` allocates a fresh `StatsViewModel()` on every tap,
        // so two sequential `.stats(_)` destinations are intentionally != —
        // the screen's month picker resets on each push, which is the desired
        // GAM-01/02 UX. This is pinned by `testStatsCardDestination_isIdentityEquatable`.
        // If persistent-across-taps state is ever desired, hoist the VM to a
        // `@State` property on HomeView (same pattern as `statsTabModel`),
        // pass it into `statsCardTapped(_:)`, and switch `.stats` to structural
        // `==` on the VM's Equatable projection. Pick one and align the test.
        static func == (lhs: Destination, rhs: Destination) -> Bool {
            switch (lhs, rhs) {
            case (.picker(let a), .picker(let b)): return a == b
            case (.errorAlert(let a), .errorAlert(let b)): return a == b
            case (.sessionStart(let a), .sessionStart(let b)): return a === b
            case (.countdown(let a), .countdown(let b)): return a === b
            case (.sessionSuccess(let a), .sessionSuccess(let b)): return a === b
            case (.scheduleList(let a), .scheduleList(let b)): return a === b
            case (.stats(let a), .stats(let b)): return a === b
            default: return false
            }
        }
    }

    /// Payload used by `.sheet(item:)` — Identifiable so each presentation gets
    /// a fresh sheet instance; Equatable for Destination Equatable conformance.
    struct PickerSession: Identifiable, Equatable {
        let id: UUID
        var selection: FamilyActivitySelection

        init(id: UUID = UUID(), selection: FamilyActivitySelection) {
            self.id = id
            self.selection = selection
        }
    }

    // MARK: - Navigation intents

    /// Triggered by HomeView "Wybierz aplikacje do blokady" CTA and by
    /// BlockedView's onChangeSelection callback (wired up in HomeView).
    func chooseAppsTapped() {
        destination = .picker(PickerSession(selection: snapshot.lastSelection))
    }

    func startSessionTapped() {
        destination = .sessionStart(SessionStartViewModel())
    }

    /// Instantiates a ScheduleListViewModel bound to HomeViewModel.destination.
    /// HomeView's bottom tab bar now owns its own ScheduleListViewModel @State
    /// (no push), so this intent is kept only for the Plan 05-07 destination
    /// contract exercised by HomeViewModelTests.
    func scheduleListTapped() {
        destination = .scheduleList(ScheduleListViewModel())
    }

    /// Tapping the home stats card pushes the full Stats screen (GAM-01 + GAM-02).
    /// Instantiates a dedicated StatsViewModel — separate from `statsCard` because
    /// the screen needs the full calendar state (displayedMonth + completedDaysSet)
    /// that the card projection doesn't carry.
    func statsCardTapped() {
        destination = .stats(StatsViewModel())
    }
}
