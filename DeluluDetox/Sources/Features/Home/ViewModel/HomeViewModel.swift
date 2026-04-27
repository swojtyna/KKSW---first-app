import Combine
@preconcurrency import FamilyControls
import Foundation
import Observation
import SwiftUINavigation
import os

@MainActor
@Observable
final class HomeViewModel: @unchecked Sendable {

    var destination: Destination?
    private(set) var snapshot: Blocklist = .empty()

    /// Home-card stats projection (CONTEXT §D-09 + §D-10). Owned by HomeViewModel
    /// so the card VM's Combine subscription lives for the home tab's lifetime
    /// (not re-created per tab switch). The same Stats pipeline feeds the
    /// pushed Stats screen via a SEPARATE StatsViewModel (created on tap).
    @ObservationIgnored
    private(set) var statsCard: HomeStatsCardViewModel = HomeStatsCardViewModel()

    @ObservationIgnored
    @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase

    @ObservationIgnored
    @LazyInjected private var updateBlocklist: UpdateBlocklistUseCase

    @ObservationIgnored
    @LazyInjected private var observeActive: ObserveActiveSessionUseCase

    @ObservationIgnored
    @LazyInjected private var observeHistory: ObserveSessionHistoryUseCase

    // Blocker 2 Option A — VM→UserDefaults boundary moved behind UCs (see Plan 03-03).
    @ObservationIgnored
    @LazyInjected private var markSuccessShown: MarkSuccessShownUseCase

    @ObservationIgnored
    @LazyInjected private var checkSuccessShown: CheckSuccessShownUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "Home"
    )

    @ObservationIgnored
    private var activeSessionId: UUID?

    init() {
        observeBlocklist.execute()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] next in self?.snapshot = next }
            .store(in: &cancellables)

        observeActive.execute()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in self?.handleActive(active) }
            .store(in: &cancellables)

        observeHistory.execute()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in self?.handleHistory(history) }
            .store(in: &cancellables)
    }

    // MARK: - Intents

    /// Called by HomeView's PickerHostView when the picker sheet dismisses.
    /// Commits the (possibly unchanged) selection via UpdateBlocklistUseCase.
    func pickerDismissed(committed selection: FamilyActivitySelection) async {
        do {
            try await updateBlocklist.execute(selection)
            logger.info(
                "blocklist updated tokens=\(selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count, privacy: .public)"
            )
            destination = nil
        } catch {
            logger.error("update failed: \(String(describing: error), privacy: .public)")
            destination = .errorAlert("Nie udało się zapisać wyboru. Spróbuj ponownie.")
        }
    }

    /// Triggered by BlockedView "Wyczyść listę" CTA (via
    /// BlockedViewModel.onClearList). Commits an empty FamilyActivitySelection
    /// through the same UpdateBlocklistUseCase path as pickerDismissed so the
    /// write uses a single code path.
    func clearBlocklistTapped() async {
        do {
            try await updateBlocklist.execute(FamilyActivitySelection())
            logger.info("blocklist cleared")
        } catch {
            logger.error("clear failed: \(String(describing: error), privacy: .public)")
            destination = .errorAlert("Nie udało się wyczyścić listy. Spróbuj ponownie.")
        }
    }

    // MARK: - Cross-VM bridge — SessionStartViewModel countdownHandoff → parent countdown
    //
    // Blocker 1 (revision 1): SessionStartViewModel signals a successful start by
    // setting its OWN destination = .countdownHandoff(record). The child VM cannot
    // navigate its parent. SessionStartView observes its own VM's destination and
    // calls this method on the parent HomeViewModel, which then replaces the
    // current .sessionStart destination with .countdown(CountdownViewModel(session: record)).
    // This is the canonical parent-owns-child-navigation pattern established in
    // Plan 02-06 (HomeView → BlockedView picker handoff).
    func gotoCountdown(_ record: SessionRecord) {
        destination = .countdown(CountdownViewModel(session: record))
        logger.info("gotoCountdown bridge fired id=\(record.id.uuidString, privacy: .public)")
    }

    // MARK: - SHL-04 deep-link routing

    /// Handle an incoming `deluludetox://` URL delivered by SwiftUI's
    /// `.onOpenURL` modifier on `AppRootView`. Per CONTEXT §D-09 / §D-10:
    ///   - `deluludetox://session/active` + active session present → countdown.
    ///   - `deluludetox://session/active` + no active session → silent home (destination = nil).
    ///   - `deluludetox://` (root / fallback shield) → destination = nil.
    ///   - Any other scheme → no-op (defensive guard).
    ///
    /// The "session just completed, success not yet shown" branch in D-10 is
    /// handled automatically by the existing `handleHistory()` observer
    /// (Plan 03-06 deliverable) — handleDeepLink only needs to clear destination
    /// in the "no active session" branch and let the observer pick up.
    func handleDeepLink(_ url: URL) async {
        guard url.scheme == "deluludetox" else {
            logger.info("deeplink ignored scheme=\(url.scheme ?? "nil", privacy: .public)")
            return
        }

        // Root URL (or any non-session host) → clear destination.
        guard url.host == "session", url.path == "/active" else {
            logger.info("deeplink root path=\(url.path, privacy: .public)")
            destination = nil
            return
        }

        // session/active path — check current active session.
        let active = await currentActiveSession()
        if let active {
            logger.info("deeplink → countdown id=\(active.id.uuidString, privacy: .public)")
            // Reuse handleActive() routing logic to avoid double-instantiating
            // CountdownViewModel when one already exists for this id.
            handleActive(active)
        } else {
            logger.info("deeplink session/active but no active session — silent home")
            destination = nil
        }
    }

    /// Synchronous-style read of the current active session value via
    /// `withCheckedContinuation` over `observeActive().first()`. Mirrors the
    /// pattern in `FinalizeSessionFromMarkerUseCase.currentActive()`
    /// (Phase 3 Plan 03-03 deliverable). Used by `handleDeepLink` to decide
    /// routing without subscribing twice to the publisher.
    private func currentActiveSession() async -> SessionRecord? {
        await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = observeActive.execute()
                .first()
                .sink { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
        }
    }

    // MARK: - Active session routing

    private func handleActive(_ active: SessionRecord?) {
        activeSessionId = active?.id

        if let active {
            // Only switch to countdown if we're not already inside .countdown for this id.
            if case .countdown(let cvm) = destination, cvm.session.id == active.id {
                return
            }
            destination = .countdown(CountdownViewModel(session: active))
            return
        }

        // Active just went nil — clear countdown destination (keep other destinations).
        if case .countdown = destination {
            destination = nil
        }
    }

    // MARK: - History routing (success screen)

    private func handleHistory(_ history: [SessionRecord]) {
        // Only consider completed outcomes — cancelled / broken do not celebrate.
        guard let mostRecentCompleted = history
            .filter({ $0.outcome == .completed })
            .sorted(by: { ($0.actualEndAt ?? .distantPast) > ($1.actualEndAt ?? .distantPast) })
            .first
        else { return }

        // Never override countdown (active session trumps success screen).
        if activeSessionId != nil { return }

        // Already shown for this id — skip (UC boundary, not direct UserDefaults).
        if checkSuccessShown.execute(sessionId: mostRecentCompleted.id) { return }

        // Only display if no other destination is currently active (don't override picker/alert).
        guard destination == nil else { return }

        // Mark shown FIRST so quick publisher re-emissions don't double-show the sheet.
        markSuccessShown.execute(sessionId: mostRecentCompleted.id)
        destination = .sessionSuccess(SessionSuccessViewModel(session: mostRecentCompleted))
    }
}
