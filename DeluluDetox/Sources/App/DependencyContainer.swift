import Observation

// TRANSITIONAL — replaced by DIContainer + distributed <Feature>Injection in 01.1-04.
// Keeps Phase 1 AppRootViewModel, OnboardingViewModel, DenialViewModel compilable
// while Repository/UseCase files migrate to feature-first layout.
//
// DELETED in 01.1-04 after all VMs use @LazyInjected and DeluluDetoxApp.init() bootstraps DIContainer.shared.

struct DependencyContainer {
    let screenTimeAuthRepository: ScreenTimeAuthRepository

    init(screenTimeAuthRepository: ScreenTimeAuthRepository = ScreenTimeAuthRepositoryImpl()) {
        self.screenTimeAuthRepository = screenTimeAuthRepository
    }

    func makeRequestScreenTimeAuthUseCase() -> RequestScreenTimeAuthUseCase {
        RequestScreenTimeAuthUseCaseImpl(repository: screenTimeAuthRepository)
    }

    func makeObserveScreenTimeAuthStatusUseCase() -> ObserveScreenTimeAuthStatusUseCase {
        ObserveScreenTimeAuthStatusUseCaseImpl(repository: screenTimeAuthRepository)
    }

    func makeRefreshScreenTimeAuthStatusUseCase() -> RefreshScreenTimeAuthStatusUseCase {
        RefreshScreenTimeAuthStatusUseCaseImpl(repository: screenTimeAuthRepository)
    }

    func makeAppRootViewModel() -> AppRootViewModel {
        AppRootViewModel(container: self)
    }

    func makeOnboardingViewModel(onAuthorized: (() -> Void)? = nil) -> OnboardingViewModel {
        OnboardingViewModel(
            requestAuth: makeRequestScreenTimeAuthUseCase(),
            onAuthorized: onAuthorized
        )
    }

    func makeDenialViewModel(onAuthorized: (() -> Void)? = nil) -> DenialViewModel {
        DenialViewModel(
            requestAuth: makeRequestScreenTimeAuthUseCase(),
            onAuthorized: onAuthorized
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel()
    }
}
