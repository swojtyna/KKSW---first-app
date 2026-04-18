import Observation

struct DependencyContainer {
    let screenTimeAuthRepository: ScreenTimeAuthRepository

    init(screenTimeAuthRepository: ScreenTimeAuthRepository = ScreenTimeAuthRepositoryImpl()) {
        self.screenTimeAuthRepository = screenTimeAuthRepository
    }

    func makeRequestScreenTimeAuthUseCase() -> RequestScreenTimeAuthUseCase {
        RequestScreenTimeAuthUseCaseImpl(repository: screenTimeAuthRepository)
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
