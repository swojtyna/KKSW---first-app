// Features/Scheduling/Injection/SchedulingInjection.swift
//
// Distributed DI registration for the Scheduling feature. Feature-owner of
// `ScheduleRepository` + `ScheduleShieldRepository` +
// `ScheduleActivityMonitoringRepository` + 7 Scheduling UseCases +
// `ConsumeScheduleEventMarkerUseCase`.
// Called from `DeluluDetoxApp.init()` BETWEEN `SessionInjection` and
// `DenialInjection`. `SelfHealSchedulesUseCase` resolves `ObserveBlocklistUseCase`
// from AppSelection which bootstraps earlier.

enum SchedulingInjection {
    static func register(in container: DIContainer) {
        // Repositories — singletons (one persistence + one store + one DAC per process).
        container.register(ScheduleRepository.self, scope: .application) { _ in
            ScheduleRepositoryImpl()
        }
        container.register(ScheduleShieldRepository.self, scope: .application) { _ in
            LiveScheduleShieldRepository()
        }
        container.register(ScheduleActivityMonitoringRepository.self, scope: .application) { _ in
            LiveScheduleActivityMonitoringRepository()
        }

        // Pure compute UC — no deps.
        container.register(ComputeScheduleWindowUseCase.self, scope: .unique) { _ in
            ComputeScheduleWindowUseCaseImpl()
        }

        // Observe UC — thin publisher pass-through.
        container.register(ObserveScheduleUseCase.self, scope: .unique) { c in
            ObserveScheduleUseCaseImpl(repository: c.resolve())
        }

        // Sync UC — register BEFORE Toggle/CreateOrUpdate (they resolve it).
        container.register(SyncScheduleWithSystemUseCase.self, scope: .unique) { c in
            SyncScheduleWithSystemUseCaseImpl(
                monitoring: c.resolve(),
                repository: c.resolve()
            )
        }

        container.register(CreateOrUpdateScheduleUseCase.self, scope: .unique) { c in
            CreateOrUpdateScheduleUseCaseImpl(
                repository: c.resolve(),
                sync: c.resolve()
            )
        }

        container.register(ToggleScheduleUseCase.self, scope: .unique) { c in
            ToggleScheduleUseCaseImpl(
                repository: c.resolve(),
                sync: c.resolve()
            )
        }

        // SelfHeal — depends on AppSelection.ObserveBlocklistUseCase (cross-feature).
        container.register(SelfHealSchedulesUseCase.self, scope: .unique) { c in
            SelfHealSchedulesUseCaseImpl(
                scheduleRepo: c.resolve(),
                shieldRepo: c.resolve(),
                observeBlocklist: c.resolve(),
                compute: c.resolve()
            )
        }

        // Main-app foreground path — consumes DAM timestamp-suffixed markers.
        container.register(ConsumeScheduleEventMarkerUseCase.self, scope: .unique) { c in
            ConsumeScheduleEventMarkerUseCaseImpl(repository: c.resolve())
        }
    }
}
