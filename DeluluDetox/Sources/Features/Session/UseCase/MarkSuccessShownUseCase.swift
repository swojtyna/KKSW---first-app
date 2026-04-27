import Foundation

/// CONTEXT §D-19 success-shown persistence boundary.
///
/// Shows the session-completed success screen **once per session** by
/// writing a per-session-id flag to a dedicated UserDefaults suite. Keeps
/// `sessions.json` clean of UI-transient state (Phase 6 gamification queries
/// sessions.json; a per-session "shown" bit doesn't belong there).
///
/// CLAUDE.md "VM → tylko UseCase" — ViewModels must not touch UserDefaults
/// directly. Mark + Check are the two UCs that wrap that read/write pair.
protocol MarkSuccessShownUseCase: Sendable {
    func execute(sessionId: UUID)
}

final class MarkSuccessShownUseCaseImpl: MarkSuccessShownUseCase, @unchecked Sendable {
    static let userDefaultsSuiteName = "com.kksw.DeluluDetox.successShown"
    static let keyPrefix = "session."

    /// Test seam — if non-nil, replaces the suite UserDefaults.
    nonisolated(unsafe) static var defaultsOverride: UserDefaults?

    private var defaults: UserDefaults {
        Self.defaultsOverride ?? (UserDefaults(suiteName: Self.userDefaultsSuiteName) ?? .standard)
    }

    func execute(sessionId: UUID) {
        defaults.set(true, forKey: "\(Self.keyPrefix)\(sessionId.uuidString)")
    }
}
