import Observation

// TRANSITIONAL -- replaced by DIContainer + distributed <Feature>Injection in 01.1-04.
// After Wave 3 (this plan): VMs use @LazyInjected over DIContainer.shared but app's
// AppRootViewModel still resolves them via DependencyContainer for Phase 1 Screen enum wiring.
// DELETED in 01.1-04.

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

    @MainActor
    func makeAppRootViewModel() -> AppRootViewModel {
        AppRootViewModel(container: self)
    }

    // After Wave 3: OnboardingVM/DenialVM use @LazyInjected, init() is arg-less.
    // This factory still exists to keep AppRootViewModel's Screen enum wiring compilable.
    // onAuthorized is assigned POST-init (the VM exposes it as `var`).
    @MainActor
    func makeOnboardingViewModel(onAuthorized: (() -> Void)? = nil) -> OnboardingViewModel {
        let vm = OnboardingViewModel()
        vm.onAuthorized = onAuthorized
        return vm
    }

    @MainActor
    func makeDenialViewModel(onAuthorized: (() -> Void)? = nil) -> DenialViewModel {
        let vm = DenialViewModel()
        vm.onAuthorized = onAuthorized
        return vm
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel()
    }
}
