import Combine
import FamilyControls
import Foundation
import Observation
import SwiftUINavigation
import os

@MainActor
@Observable
final class AppRootViewModel: @unchecked Sendable {

    @CasePathable
    enum Destination: Equatable {
        case onboarding
        case denial
        case home
    }

    var destination: Destination?

    @ObservationIgnored
    @LazyInjected private var observeStatus: ObserveScreenTimeAuthStatusUseCase
    @ObservationIgnored
    @LazyInjected private var refreshStatusUseCase: RefreshScreenTimeAuthStatusUseCase
    // Phase 02 (SEL-05): AppRoot fires reconcile on scenePhase == .active so the
    // blocklists.json token pointers get refreshed next time the user engages.
    @ObservationIgnored
    @LazyInjected private var reconcileBlocklist: ReconcileBlocklistUseCase
    // Phase 03 — Session self-heal + finalize + revocation UCs.
    @ObservationIgnored
    @LazyInjected private var finalizeFromMarker: FinalizeSessionFromMarkerUseCase
    @ObservationIgnored
    @LazyInjected private var selfHealExpiredSession: SelfHealExpiredSessionUseCase
    @ObservationIgnored
    @LazyInjected private var detectRevocation: DetectRevocationUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "AppRoot")

    /// Darwin notification name posted by the DAM extension on `intervalDidEnd`.
    /// MUST match `DeviceActivityMonitorExtension.darwinSessionFinalizedName`.
    /// Without this subscriber the countdown screen freezes at 00:00 when the
    /// timer expires while the app is foregrounded — the shield clears (DAM did
    /// it) but `activeSubject` never updates, so HomeViewModel never drops the
    /// `.countdown` destination. CR-02 from 03-REVIEW.md.
    @ObservationIgnored
    private static let darwinSessionFinalizedName = "com.kksw.DeluluDetox.sessionFinalized"

    init() {
        observeStatus()
            .sink { [weak self] status in
                self?.destination = Self.map(status)
            }
            .store(in: &cancellables)

        registerDarwinFinalizeObserver()
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(center, observer)
    }

    /// Wywoływane przez AppRootView na `scenePhase == .active` (D-14 + SEL-05).
    /// 1) Odświeża Screen Time auth status (core-value guard).
    /// 2) Reconcile blocklist (Phase 02).
    /// 3) Consume DAM finalize marker (Phase 03 §D-03).
    /// 4) Self-heal expired session (Phase 03 §D-02).
    /// 5) Detect revocation (Phase 03 §D-11).
    /// Steps 2-5 are fire-and-forget — errors are logged but never cancel navigation.
    func refreshStatus() {
        refreshStatusUseCase()
        // Capture UC references eagerly on @MainActor so @LazyInjected resolves
        // while DIContainer is still populated (before any async Task yields).
        let reconcile = reconcileBlocklist
        let finalize = finalizeFromMarker
        let selfHeal = selfHealExpiredSession
        let revocation = detectRevocation
        let log = logger
        Task {
            let now = Date()

            // Phase 02 — blocklist reconcile.
            do {
                try await reconcile()
            } catch {
                log.error("reconcile failed: \(String(describing: error), privacy: .public)")
            }

            // Phase 03 — marker consumption (DAM-written finalize marker).
            do {
                _ = try await finalize(now: now)
            } catch {
                log.error("finalizeFromMarker failed: \(String(describing: error), privacy: .public)")
            }

            // Phase 03 — self-heal if DAM callback regressed (CONTEXT §D-02).
            do {
                _ = try await selfHeal(now: now)
            } catch {
                log.error("selfHealExpiredSession failed: \(String(describing: error), privacy: .public)")
            }

            // Phase 03 — revocation detection (CONTEXT §D-11).
            do {
                _ = try await revocation(now: now)
            } catch {
                log.error("detectRevocation failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Subscribe to the Darwin notification posted by the DAM extension's
    /// `intervalDidEnd` so a foregrounded main app reacts immediately instead
    /// of waiting for the next scenePhase transition. Bridges a CoreFoundation
    /// callback to `refreshStatus()` on `@MainActor`.
    private func registerDarwinFinalizeObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let name = CFNotificationName(Self.darwinSessionFinalizedName as CFString)
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let vm = Unmanaged<AppRootViewModel>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    vm.refreshStatus()
                }
            },
            name.rawValue,
            nil,
            .deliverImmediately
        )
        logger.info("darwin observer registered: \(Self.darwinSessionFinalizedName, privacy: .public)")
    }

    private static func map(_ status: AuthorizationStatus) -> Destination {
        switch status {
        case .approved: return .home
        case .denied: return .denial
        default: return .onboarding
        }
    }
}
