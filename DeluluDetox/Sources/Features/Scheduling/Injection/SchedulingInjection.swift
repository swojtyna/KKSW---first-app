// Features/Scheduling/Injection/SchedulingInjection.swift
//
// Distributed DI registration for the Scheduling feature. Feature-owner of
// `ScheduleRepository` + `ScheduleShieldRepository` +
// `ScheduleActivityMonitoringRepository` + 7 Scheduling UseCases.
// Called from `DeluluDetoxApp.init()` BETWEEN `SessionInjection` and
// `DenialInjection`. Scheduling depends on AppSelection (Blocklist) and
// Session (no direct dep, but bootstraps after so BlocklistRepository
// is registered before SelfHealSchedulesUseCase resolves it).
//
// Plan 05-01: skeleton only (empty body). Plan 05-04 adds 3 repo +
// 7 UC registrations.

enum SchedulingInjection {
    static func register(in container: DIContainer) {
        // Intentionally empty until Plan 05-04.
        // Downstream plans add repository + UC registrations here.
        _ = container
    }
}
