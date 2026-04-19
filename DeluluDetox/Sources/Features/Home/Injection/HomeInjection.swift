// Features/Home/Injection/HomeInjection.swift
//
// No-op: HomeViewModel has no UseCase dependencies in Phase 01.1 (D-15).
// Phase 2 will add the first UseCase (e.g., PickBlockedAppsUseCase) and corresponding registration.
// Plik istnieje dla architektonicznej symetrii.

enum HomeInjection {
    static func register(in container: DIContainer) {
        // No-op by design in Phase 01.1.
    }
}
