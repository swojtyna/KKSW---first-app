import Combine
import Foundation
import Observation
import SwiftUINavigation
import os

/// @Observable ViewModel for the Schedule List screen (SCH-01 entry + SCH-02 quick toggle).
///
/// CLAUDE.md / architecture guide invariant: ViewModels must not import SwiftUI.
/// `SwiftUINavigation` is the pointfree swift-navigation library (provides
/// `@CasePathable`) — it is NOT the SwiftUI framework, so importing it here is
/// the sanctioned pattern (mirrors `SessionStartViewModel`, `ScheduleEditorViewModel`).
///
/// Behaviour (Plan 05-07):
/// - Observes `ObserveScheduleUseCase()` publisher → mirrors its emissions into `schedules`.
/// - `createTapped()` / `editTapped(_:)` push a `ScheduleEditorViewModel` onto `destination`.
/// - `toggleSchedule(scheduleId:enabled:)` delegates to `ToggleScheduleUseCase` (SCH-02 row-level flip).
@MainActor
@Observable
final class ScheduleListViewModel: @unchecked Sendable {

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

    var destination: Destination?
    private(set) var schedules: [Schedule] = []

    @ObservationIgnored
    @LazyInjected private var observeSchedule: ObserveScheduleUseCase
    @ObservationIgnored
    @LazyInjected private var toggleScheduleUC: ToggleScheduleUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "ScheduleList"
    )

    init() {
        observeSchedule()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.schedules = list
            }
            .store(in: &cancellables)
    }

    // MARK: - Intents

    func createTapped() {
        destination = .scheduleEditor(ScheduleEditorViewModel(existing: nil))
    }

    func editTapped(_ schedule: Schedule) {
        destination = .scheduleEditor(ScheduleEditorViewModel(existing: schedule))
    }

    func toggleSchedule(scheduleId: UUID, enabled: Bool) async {
        do {
            try await toggleScheduleUC(scheduleId: scheduleId, enabled: enabled)
            logger.info(
                "schedule toggled id=\(scheduleId.uuidString, privacy: .public) enabled=\(enabled, privacy: .public)"
            )
        } catch {
            logger.error("toggle failed: \(String(describing: error), privacy: .public)")
            destination = .errorAlert("Nie udało się przełączyć — kliknij jeszcze raz.")
        }
    }

    func clearDestination() {
        destination = nil
    }
}
