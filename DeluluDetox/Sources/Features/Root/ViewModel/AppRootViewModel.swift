import Observation
import Combine
import FamilyControls
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
    // Cross-feature UC consumption is the sanctioned path per 02-RESEARCH.md §Pattern 3.
    @ObservationIgnored
    @LazyInjected private var reconcileBlocklist: ReconcileBlocklistUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "AppRoot"
    )

    init() {
        observeStatus()
            .sink { [weak self] status in
                self?.destination = Self.map(status)
            }
            .store(in: &cancellables)
    }

    /// Wywoływane przez AppRootView na `scenePhase == .active` (D-14 + SEL-05).
    /// 1) Odświeża Screen Time auth status (core-value guard).
    /// 2) Odpala reconcile blocklist — fire-and-forget; błąd jest logowany,
    ///    ale nie zmienia destination i nie crashuje.
    func refreshStatus() {
        refreshStatusUseCase()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.reconcileBlocklist()
            } catch {
                self.logger.error(
                    "reconcile failed: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    private static func map(_ status: AuthorizationStatus) -> Destination {
        switch status {
        case .approved:
            return .home
        case .denied:
            return .denial
        default:
            return .onboarding
        }
    }
}
