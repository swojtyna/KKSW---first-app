// Features/Stats/Injection/StatsInjection.swift
//
// Distributed DI registration for the Stats feature. Feature-owner of
// `ComputeStatsUseCase` + `ObserveStatsUseCase`. Called from `DeluluDetoxApp.init()`
// AFTER SessionInjection (resolves `ObserveSessionHistoryUseCase`).

enum StatsInjection {
    static func register(in container: DIContainer) {
        container.register(ComputeStatsUseCase.self, scope: .unique) { _ in
            ComputeStatsUseCaseImpl()
        }
        container.register(ObserveStatsUseCase.self, scope: .unique) { c in
            ObserveStatsUseCaseImpl(
                observeHistory: c.resolve(),
                compute: c.resolve()
            )
        }
    }
}
