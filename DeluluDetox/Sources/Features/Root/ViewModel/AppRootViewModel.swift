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
    // Phase 05 — Scheduling marker consumption + self-heal UCs.
    @ObservationIgnored
    @LazyInjected private var consumeScheduleMarker: ConsumeScheduleEventMarkerUseCase
    @ObservationIgnored
    @LazyInjected private var selfHealSchedules: SelfHealSchedulesUseCase
    // Phase 06 §H4 — NTF-02 foreground reconcile. Publisher snapshot via
    // first()-sink; reconcile each schedule (enabled + disabled) so pending
    // requests stay in lockstep even if iOS evicted pending requests.
    @ObservationIgnored
    @LazyInjected private var observeSchedule: ObserveScheduleUseCase
    @ObservationIgnored
    @LazyInjected private var reconcileScheduleNotifications: ReconcileScheduleNotificationsUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "AppRoot")

    /// SHL-03 fallback channel — `ShieldDeepLinkNotificationDelegate` sends
    /// tapped-notification URLs here; `AppRootView.onReceive` forwards to
    /// `homeModel.handleDeepLink`. Wzorzec B per navigation GUIDE.md: child
    /// event → parent repository → sibling .sink. The subject is exposed as
    /// `AnyPublisher` to forbid external sends.
    @ObservationIgnored
    private let deepLinkSubject = PassthroughSubject<URL, Never>()

    var deepLinkPublisher: AnyPublisher<URL, Never> { deepLinkSubject.eraseToAnyPublisher() }

    func ingestShieldDeepLink(_ url: URL) {
        deepLinkSubject.send(url)
    }

    /// Darwin notification name posted by the DAM extension on `intervalDidEnd`.
    /// MUST match `DeviceActivityMonitorExtension.darwinSessionFinalizedName`.
    /// Without this subscriber the countdown screen freezes at 00:00 when the
    /// timer expires while the app is foregrounded — the shield clears (DAM did
    /// it) but `activeSubject` never updates, so HomeViewModel never drops the
    /// `.countdown` destination. CR-02 from 03-REVIEW.md.
    @ObservationIgnored
    private static let darwinSessionFinalizedName = "com.kksw.DeluluDetox.sessionFinalized"
    /// Phase 05 — DAM posts these on schedule interval boundaries so the main
    /// app can react immediately when foregrounded (no scenePhase wait).
    @ObservationIgnored
    private static let darwinScheduleStartedName = "com.kksw.DeluluDetox.scheduleStarted"
    @ObservationIgnored
    private static let darwinScheduleEndedName = "com.kksw.DeluluDetox.scheduleEnded"

    init() {
        observeStatus()
            .sink { [weak self] status in
                self?.destination = Self.map(status)
            }
            .store(in: &cancellables)

        registerDarwinObservers()
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
        let consumeScheduleMarker = self.consumeScheduleMarker
        let selfHealSchedules = self.selfHealSchedules
        let observeSchedule = self.observeSchedule
        let reconcileScheduleNotifications = self.reconcileScheduleNotifications
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

            // Phase 05 — schedule marker consumption BEFORE self-heal
            // (RESEARCH §Pitfall 8: events must be ingested before the
            // reconciliation pass decides apply/clear).
            do {
                _ = try await consumeScheduleMarker()
            } catch {
                log.error("consumeScheduleMarker failed: \(String(describing: error), privacy: .public)")
            }

            // Phase 05 — schedule self-heal (CONTEXT §D-18).
            do {
                _ = try await selfHealSchedules(now: now)
            } catch {
                log.error("selfHealSchedules failed: \(String(describing: error), privacy: .public)")
            }

            // Phase 06 §H4 — NTF-02 foreground reliability reconcile. Each
            // invocation removes-and-re-adds pending `schedule.start.{id}.*`
            // for every schedule in the current publisher snapshot (enabled
            // AND disabled — the UC itself handles enabled=false by removing
            // stale). Idempotent; safe to call every foreground.
            let schedules = await Self.firstSchedulesSnapshot(observeSchedule)
            for schedule in schedules {
                await reconcileScheduleNotifications(schedule: schedule)
            }
        }
    }

    /// First-value snapshot of `ObserveScheduleUseCase()`. Combine `.first()`
    /// + `.sink` bridge to async; cancellable cancels after resume.
    private static func firstSchedulesSnapshot(_ observe: ObserveScheduleUseCase) async -> [Schedule] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[Schedule], Never>) in
            var cancellable: AnyCancellable?
            cancellable = observe()
                .first()
                .sink { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
        }
    }

    /// Subscribe to the Darwin notification posted by the DAM extension's
    /// `intervalDidEnd` so a foregrounded main app reacts immediately instead
    /// of waiting for the next scenePhase transition. Bridges a CoreFoundation
    /// callback to `refreshStatus()` on `@MainActor`.
    private func registerDarwinObservers() {
        registerDarwinObserver(name: Self.darwinSessionFinalizedName)
        registerDarwinObserver(name: Self.darwinScheduleStartedName)
        registerDarwinObserver(name: Self.darwinScheduleEndedName)
    }

    private func registerDarwinObserver(name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let cfName = CFNotificationName(name as CFString)
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
            cfName.rawValue,
            nil,
            .deliverImmediately
        )
        logger.info("darwin observer registered: \(name, privacy: .public)")
    }

    private static func map(_ status: AuthorizationStatus) -> Destination {
        switch status {
        case .approved: return .home
        case .denied: return .denial
        default: return .onboarding
        }
    }
}
