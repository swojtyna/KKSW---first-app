// Features/Root/Injection/RootInjection.swift
//
// No-op: AppRootViewModel depends SOLELY on UseCases registered by OnboardingInjection (D-01, D-17).
// File exists for architectural symmetry — Phase 4 (shield deep links) may add Root-scoped UC here.

enum RootInjection {
    static func register(in container: DIContainer) {
        // No-op by design in Phase 01.1.
    }
}
