import Combine
@preconcurrency import FamilyControls
import Foundation
import Observation
import SwiftUINavigation
import os

@MainActor
@Observable
final class HomeViewModel: @unchecked Sendable {

    @CasePathable
    enum Destination: Equatable {
        case picker(PickerSession)
        case errorAlert(String)
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

    var destination: Destination?
    private(set) var snapshot: Blocklist = .empty()

    @ObservationIgnored
    @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase

    @ObservationIgnored
    @LazyInjected private var updateBlocklist: UpdateBlocklistUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "Home"
    )

    init() {
        observeBlocklist()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] next in self?.snapshot = next }
            .store(in: &cancellables)
    }

    /// Triggered by HomeView "Wybierz aplikacje do blokady" CTA and by
    /// BlockedView's onChangeSelection callback (wired up in HomeView).
    func chooseAppsTapped() {
        destination = .picker(PickerSession(selection: snapshot.lastSelection))
    }

    /// Called by HomeView's PickerHostView when the picker sheet dismisses.
    /// Commits the (possibly unchanged) selection via UpdateBlocklistUseCase.
    func pickerDismissed(committed selection: FamilyActivitySelection) async {
        do {
            try await updateBlocklist(selection)
            logger.info(
                "blocklist updated tokens=\(selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count, privacy: .public)"
            )
            destination = nil
        } catch {
            logger.error("update failed: \(String(describing: error), privacy: .public)")
            destination = .errorAlert("Nie udało się zapisać wyboru. Spróbuj ponownie.")
        }
    }
}
