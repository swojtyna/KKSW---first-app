// Features/Denial/Injection/DenialInjection.swift
//
// No-op: Denial feature consumes RequestScreenTimeAuthUseCase registered by OnboardingInjection.
// This file exists for architectural symmetry and future registration slots.
// Per D-17: shared components live under feature-owner's directory (Onboarding).

enum DenialInjection {
    static func register(in container: DIContainer) {
        // No-op by design. Denial has no feature-owned dependencies in Phase 01.1.
    }
}
