// Features/AppSelection/Injection/AppSelectionInjection.swift
//
// Distributed DI registration for the AppSelection feature — feature-owner of
// the Blocklist domain (Repository, Models, UseCases). Called from
// DeluluDetoxApp.init() between OnboardingInjection and DenialInjection.
//
// Home consumes ObserveBlocklistUseCase + UpdateBlocklistUseCase across the
// feature boundary (sanctioned cross-feature UC consumption per 02-RESEARCH.md
// §Pattern 3 — Denial → Onboarding precedent).

enum AppSelectionInjection {
    static func register(in container: DIContainer) {
        container.register(BlocklistRepository.self, scope: .application) { _ in
            BlocklistRepositoryImpl()
        }
        container.register(ObserveBlocklistUseCase.self, scope: .unique) { c in
            ObserveBlocklistUseCaseImpl(repository: c.resolve())
        }
        container.register(UpdateBlocklistUseCase.self, scope: .unique) { c in
            UpdateBlocklistUseCaseImpl(repository: c.resolve())
        }
        container.register(RemoveTokenRecordUseCase.self, scope: .unique) { c in
            RemoveTokenRecordUseCaseImpl(repository: c.resolve())
        }
        container.register(ReconcileBlocklistUseCase.self, scope: .unique) { c in
            ReconcileBlocklistUseCaseImpl(repository: c.resolve())
        }
    }
}
