import Combine
import Foundation
import Observation
import SwiftUINavigation
import os

/// @Observable ViewModel for the session Start screen. Owns the preset/custom
/// duration UX (QSN-01 + QSN-02), the blocklist-empty gate (CONTEXT §D-06), and
/// the already-active-session gate (CONTEXT §D-05).
///
/// No SwiftUI import — SwiftUINavigation is the swift-navigation library, not
/// the SwiftUI framework.
@MainActor
@Observable
final class SessionStartViewModel: @unchecked Sendable {

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

    var destination: Destination?

    // MARK: Selection state

    private(set) var selectedPresetMinutes: Int? = 30
    var customDurationSeconds: Int = 30 * 60 {
        didSet {
            // Clamp silently so the SwiftUI DatePicker binding can't push out-of-range.
            if customDurationSeconds < SessionDuration.minSeconds {
                customDurationSeconds = SessionDuration.minSeconds
            }
            if customDurationSeconds > SessionDuration.maxSeconds {
                customDurationSeconds = SessionDuration.maxSeconds
            }
        }
    }

    // MARK: Snapshot inputs

    private(set) var blocklistHasRecords: Bool = false
    private(set) var hasActiveSession: Bool = false
    private(set) var isStarting: Bool = false

    private var latestBlocklistId: UUID?
    private var latestActive: SessionRecord?

    // MARK: Derived

    var resolvedDuration: SessionDuration? {
        if let preset = selectedPresetMinutes {
            return SessionDuration.preset(preset)
        }
        return SessionDuration(seconds: customDurationSeconds)
    }

    var canStart: Bool { blocklistHasRecords && !isStarting && resolvedDuration != nil }

    // MARK: DI

    @ObservationIgnored
    @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase
    @ObservationIgnored
    @LazyInjected private var observeActive: ObserveActiveSessionUseCase
    @ObservationIgnored
    @LazyInjected private var startSession: StartSessionUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "SessionStartVM"
    )

    init() {
        observeBlocklist()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] blocklist in
                guard let self else { return }
                self.blocklistHasRecords = !blocklist.records.isEmpty
                self.latestBlocklistId = blocklist.id
            }
            .store(in: &cancellables)

        observeActive()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                guard let self else { return }
                self.hasActiveSession = (active != nil)
                self.latestActive = active
            }
            .store(in: &cancellables)
    }

    // MARK: Intents

    func selectPreset(_ minutes: Int) {
        selectedPresetMinutes = minutes
    }

    func switchToCustom() {
        selectedPresetMinutes = nil
    }

    func startTapped(now: Date) async {
        // Gate 1: already an active session → route to sessionInProgress handoff.
        if let active = latestActive {
            destination = .sessionInProgress(active)
            return
        }
        // Gate 2: blocklist empty.
        guard blocklistHasRecords, let blocklistId = latestBlocklistId else {
            logger.info("startTapped ignored: blocklist empty")
            return
        }
        // Gate 3: duration out of range.
        guard let duration = resolvedDuration else {
            logger.info("startTapped ignored: duration out of range")
            return
        }
        // Gate 4: re-entry guard.
        guard !isStarting else { return }

        isStarting = true
        defer { isStarting = false }

        do {
            let record = try await startSession(
                blocklistId: blocklistId,
                duration: duration,
                now: now
            )
            destination = .countdownHandoff(record)
            logger.info("session start ok id=\(record.id.uuidString, privacy: .public)")
        } catch {
            logger.error("session start failed: \(String(describing: error), privacy: .public)")
            destination = .errorAlert("Coś poszło nie tak. Timer nie wystartował — spróbuj jeszcze raz.")
        }
    }

    func clearDestination() {
        destination = nil
    }
}
