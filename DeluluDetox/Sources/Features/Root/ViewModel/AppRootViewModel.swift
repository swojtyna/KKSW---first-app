import Observation
import Combine
import FamilyControls
import SwiftUINavigation

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

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    init() {
        observeStatus()
            .sink { [weak self] status in
                self?.destination = Self.map(status)
            }
            .store(in: &cancellables)
    }

    /// Wywoływane przez AppRootView na `scenePhase == .active` (D-14).
    /// Zamyka core-value dziurę: user cofa Screen Time w Settings → repo emituje nowy status → destination się zmienia.
    func refreshStatus() {
        refreshStatusUseCase()
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
