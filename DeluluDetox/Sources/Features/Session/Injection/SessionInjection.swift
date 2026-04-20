// Features/Session/Injection/SessionInjection.swift
//
// Distributed DI registration for the Session feature. Feature-owner of
// `SessionRepository` + `SessionShieldRepository` + `SessionActivityMonitoringRepository`
// + 9 Session UseCases. Called from `DeluluDetoxApp.init()` BETWEEN
// `AppSelectionInjection` and `DenialInjection` (feature-owner-first ordering
// per 02-03 SUMMARY §"Bootstrap ordering").

enum SessionInjection {
    static func register(in container: DIContainer) {
        // Repository (singleton — one CurrentValueSubject per process).
        container.register(SessionRepository.self, scope: .application) { _ in
            SessionRepositoryImpl()
        }

        // Shield repository (singleton — one ManagedSettingsStore wrapper per process).
        container.register(SessionShieldRepository.self, scope: .application) { _ in
            LiveSessionShieldRepository()
        }

        // Activity monitoring repository (singleton — one DeviceActivityCenter per process).
        container.register(SessionActivityMonitoringRepository.self, scope: .application) { _ in
            LiveSessionActivityMonitoringRepository()
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
            EndSessionUseCaseImpl(
                repository: c.resolve(),
                shield: c.resolve(),
                monitoring: c.resolve(),
                cancelEndNotification: c.resolve()   // Plan 06-03 §H2
            )
        }
        container.register(StartSessionUseCase.self, scope: .unique) { c in
            StartSessionUseCaseImpl(
                repository: c.resolve(),
                shield: c.resolve(),
                monitoring: c.resolve(),
                observeBlocklist: c.resolve(),
                scheduleEndNotification: c.resolve()  // Plan 06-03 §H1
            )
        }
        container.register(FinalizeSessionFromMarkerUseCase.self, scope: .unique) { c in
            FinalizeSessionFromMarkerUseCaseImpl(
                repository: c.resolve(),
                endSession: c.resolve(),
                schedulePermissionPrompt: c.resolve()   // Plan 06-03 D-13
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
