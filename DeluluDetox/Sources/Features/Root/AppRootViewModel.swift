import Observation
import FamilyControls

@Observable
final class AppRootViewModel {
    enum Screen {
        case onboarding(OnboardingViewModel)
        case denial(DenialViewModel)
        case home(HomeViewModel)
    }

    private(set) var screen: Screen

    var screenTag: Int {
        switch screen {
        case .onboarding: 0
        case .denial: 1
        case .home: 2
        }
    }

    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        let status = container.screenTimeAuthRepository.authorizationStatus
        switch status {
        case .approved:
            self.screen = .home(container.makeHomeViewModel())
        default:
            self.screen = .onboarding(
                container.makeOnboardingViewModel(onAuthorized: nil)
            )
        }
        // Wire the onAuthorized callback after init
        if case .onboarding(let vm) = screen {
            vm.onAuthorized = { [weak self] in self?.checkAuthorization() }
        }
    }

    func checkAuthorization() {
        let status = container.screenTimeAuthRepository.authorizationStatus
        switch status {
        case .approved:
            screen = .home(container.makeHomeViewModel())
        case .denied:
            let vm = container.makeDenialViewModel(
                onAuthorized: { [weak self] in self?.checkAuthorization() }
            )
            screen = .denial(vm)
        default:
            let vm = container.makeOnboardingViewModel(
                onAuthorized: { [weak self] in self?.checkAuthorization() }
            )
            screen = .onboarding(vm)
        }
    }
}
