import Foundation

/// Reads the per-session "success-shown" flag persisted by `MarkSuccessShownUseCase`.
/// Wraps UserDefaults so VMs remain UI-only (CLAUDE.md "VM → tylko UseCase").
protocol CheckSuccessShownUseCase: Sendable {
    func callAsFunction(sessionId: UUID) -> Bool
}

final class CheckSuccessShownUseCaseImpl: CheckSuccessShownUseCase, @unchecked Sendable {
    private var defaults: UserDefaults {
        MarkSuccessShownUseCaseImpl.defaultsOverride
            ?? (UserDefaults(suiteName: MarkSuccessShownUseCaseImpl.userDefaultsSuiteName) ?? .standard)
    }

    func callAsFunction(sessionId: UUID) -> Bool {
        defaults.bool(forKey: "\(MarkSuccessShownUseCaseImpl.keyPrefix)\(sessionId.uuidString)")
    }
}
