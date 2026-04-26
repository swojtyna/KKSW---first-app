// Features/Onboarding/Injection/OnboardingInjection.swift
//
// Distributed DI registration for the Onboarding feature (feature-owner of ScreenTimeAuth*).
// Called from DeluluDetoxApp.init() in Wave 5 bootstrap. Not wired yet in this plan.

enum OnboardingInjection {
    static func register(in container: DIContainer) {
        container.register(ScreenTimeAuthRepository.self, scope: .application) { _ in
            ScreenTimeAuthRepositoryImpl()
        }
        container.register(NotificationsOnboardingRepository.self, scope: .application) { _ in
            NotificationsOnboardingRepositoryImpl()
        }
        container.register(CompleteNotificationsOnboardingUseCase.self, scope: .unique) { c in
            CompleteNotificationsOnboardingUseCaseImpl(repository: c.resolve())
        }
        container.register(ObserveNotificationsOnboardingCompletionUseCase.self, scope: .unique) { c in
            ObserveNotificationsOnboardingCompletionUseCaseImpl(repository: c.resolve())
        }
        container.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { c in
            RequestScreenTimeAuthUseCaseImpl(repository: c.resolve())
        }
        container.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { c in
            ObserveScreenTimeAuthStatusUseCaseImpl(repository: c.resolve())
        }
        container.register(RefreshScreenTimeAuthStatusUseCase.self, scope: .unique) { c in
            RefreshScreenTimeAuthStatusUseCaseImpl(repository: c.resolve())
        }
    }
}
