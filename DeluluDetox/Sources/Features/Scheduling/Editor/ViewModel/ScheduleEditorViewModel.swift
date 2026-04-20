import Combine
import Foundation
import Observation
import SwiftUINavigation
import os

/// @Observable ViewModel for the Schedule Editor screen (SCH-01 + SCH-02 main entry).
///
/// CLAUDE.md / architecture guide invariant: ViewModels must not import SwiftUI.
/// `SwiftUINavigation` is the pointfree swift-navigation library (provides
/// `@CasePathable`) — it is NOT the SwiftUI framework, so importing it here is
/// the sanctioned pattern (mirrors `SessionStartViewModel`).
@MainActor
@Observable
final class ScheduleEditorViewModel: @unchecked Sendable {

    @CasePathable
    enum Destination: Equatable {
        /// Sarcastic Polish error toast — CONTEXT §D-14.
        case errorAlert(String)
    }

    var destination: Destination?

    // MARK: Draft fields

    var daysOfWeek: Set<Int>   // Calendar.weekday values: 1=Sun..7=Sat
    var startHour: Int         // 0..23
    var startMinute: Int       // 0..59
    var endHour: Int           // 0..23
    var endMinute: Int         // 0..59
    var enabled: Bool
    private(set) var isSaving: Bool = false

    // MARK: Derived

    /// True when `(endHour, endMinute) <= (startHour, startMinute)` — schedule wraps past midnight (D-03).
    var isCrossMidnight: Bool {
        let startMin = startHour * 60 + startMinute
        let endMin = endHour * 60 + endMinute
        return endMin <= startMin
    }

    /// Save is gated: must have at least one selected day and not already in flight.
    var canSave: Bool { !isSaving && !daysOfWeek.isEmpty }

    // MARK: Identity

    private let editingId: UUID?
    private var blocklistId: UUID?
    private let appVersion: String

    // MARK: DI

    @ObservationIgnored
    @LazyInjected private var createOrUpdate: CreateOrUpdateScheduleUseCase
    @ObservationIgnored
    @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "ScheduleEditorVM"
    )

    // MARK: Preset weekday sets

    private static let workdayWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    private static let weekendWeekdays: Set<Int> = [7, 1]
    private static let allWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    // MARK: Init

    init(existing: Schedule? = nil, appVersion: String = "1.0") {
        self.editingId = existing?.id
        self.appVersion = appVersion

        if let s = existing {
            self.daysOfWeek = Set(s.daysOfWeek)
            self.startHour = s.startHour
            self.startMinute = s.startMinute
            self.endHour = s.endHour
            self.endMinute = s.endMinute
            self.enabled = s.enabled
            self.blocklistId = s.blocklistId
        } else {
            self.daysOfWeek = []
            self.startHour = 9
            self.startMinute = 0
            self.endHour = 17
            self.endMinute = 0
            self.enabled = true
            self.blocklistId = nil
        }

        // Resolve the implicit single blocklist id from Phase 2 on init.
        // `.receive(on: .main)` is REQUIRED: BlocklistRepository emits from
        // whatever thread invoked `send(...)` — when AppRootViewModel.refreshStatus
        // triggers `reconcileBlocklist()` in its non-isolated Task, the subject
        // sends on the cooperative thread pool. Without this hop, the sink
        // closure would mutate a `@MainActor` property off-main, tripping
        // Swift 6's `swift_task_isCurrentExecutorWithFlagsImpl` assertion
        // (observed on device: `dispatch_assert_queue_fail` after a Darwin
        // scheduleStarted cascade while the Editor was still alive post-save).
        observeBlocklist()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] blocklist in
                guard let self else { return }
                if self.blocklistId == nil {
                    self.blocklistId = blocklist.id
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Intents

    func applyPresetDniRobocze() { daysOfWeek = Self.workdayWeekdays }
    func applyPresetWeekend() { daysOfWeek = Self.weekendWeekdays }
    func applyPresetCodziennie() { daysOfWeek = Self.allWeekdays }

    func toggleDay(_ weekday: Int) {
        if daysOfWeek.contains(weekday) {
            daysOfWeek.remove(weekday)
        } else {
            daysOfWeek.insert(weekday)
        }
    }

    /// Persist via `CreateOrUpdateScheduleUseCase`. Returns `true` on success so
    /// the View can dismiss; `false` on failure (errorAlert populated instead).
    @discardableResult
    func saveTapped() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        guard let blocklistId else {
            destination = .errorAlert("Nie mogę zapisać — brak blocklisty. Dodaj najpierw apki do blokady.")
            return false
        }

        let schedule = Schedule(
            id: editingId ?? UUID(),
            name: nil,
            daysOfWeek: Array(daysOfWeek).sorted(),
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            enabled: enabled,
            blocklistId: blocklistId,
            appVersion: appVersion
        )

        do {
            try await createOrUpdate(schedule)
            logger.info(
                "schedule saved id=\(schedule.id.uuidString, privacy: .public) enabled=\(schedule.enabled, privacy: .public)"
            )
            return true
        } catch {
            logger.error("save failed: \(String(describing: error), privacy: .public)")
            destination = .errorAlert("iOS się zbuntował, spróbuj jeszcze raz.")
            return false
        }
    }

    func clearDestination() {
        destination = nil
    }
}
