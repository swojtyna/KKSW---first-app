// Features/Session/Injection/SessionInjection.swift
//
// Distributed DI registration for the Session feature. Feature-owner of
// `SessionRepository` + `SessionEnforcer` + 9 Session UseCases. Called from
// `DeluluDetoxApp.init()` BETWEEN `AppSelectionInjection` and `DenialInjection`
// (feature-owner-first ordering per 02-03 SUMMARY §"Bootstrap ordering").

enum SessionInjection {
    static func register(in container: DIContainer) {
        // Repository (singleton — one CurrentValueSubject per process).
        container.register(SessionRepository.self, scope: .application) { _ in
            SessionRepositoryImpl()
        }

        // Enforcer (singleton — one ManagedSettingsStore wrapper per process).
        container.register(SessionEnforcer.self, scope: .application) { _ in
            SessionEnforcerImpl()
        }

        // Observe UCs — stateless pass-through wrappers.
        container.register(ObserveActiveSessionUseCase.self, scope: .unique) { c in
            ObserveActiveSessionUseCaseImpl(repository: c.resolve())
        }
        container.register(ObserveSessionHistoryUseCase.self, scope: .unique) { c in
            ObserveSessionHistoryUseCaseImpl(repository: c.resolve())
        }

        // EndSession MUST register BEFORE the UCs that depend on it
        // (Finalize/SelfHeal/DetectRevocation all resolve EndSessionUseCase).
        container.register(EndSessionUseCase.self, scope: .unique) { c in
            EndSessionUseCaseImpl(repository: c.resolve(), enforcer: c.resolve())
        }
        container.register(StartSessionUseCase.self, scope: .unique) { c in
            StartSessionUseCaseImpl(
                repository: c.resolve(),
                enforcer: c.resolve(),
                observeBlocklist: c.resolve()
            )
        }
        container.register(FinalizeSessionFromMarkerUseCase.self, scope: .unique) { c in
            FinalizeSessionFromMarkerUseCaseImpl(
                repository: c.resolve(),
                endSession: c.resolve()
            )
        }
        container.register(SelfHealExpiredSessionUseCase.self, scope: .unique) { c in
            SelfHealExpiredSessionUseCaseImpl(
                repository: c.resolve(),
                endSession: c.resolve()
            )
        }
        container.register(DetectRevocationUseCase.self, scope: .unique) { c in
            DetectRevocationUseCaseImpl(
                repository: c.resolve(),
                endSession: c.resolve()
            )
        }

        // Success-shown flag UCs (CONTEXT §D-19 + CLAUDE.md "VM → tylko UseCase").
        // Stateless wrappers around UserDefaults; VMs inject these instead of
        // touching UserDefaults directly.
        container.register(MarkSuccessShownUseCase.self, scope: .unique) { _ in
            MarkSuccessShownUseCaseImpl()
        }
        container.register(CheckSuccessShownUseCase.self, scope: .unique) { _ in
            CheckSuccessShownUseCaseImpl()
        }
    }
}
