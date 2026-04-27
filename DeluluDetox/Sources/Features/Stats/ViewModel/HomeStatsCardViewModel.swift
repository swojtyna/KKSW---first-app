import Combine
import Foundation
import Observation

/// @Observable VM for the home screen stats card (CONTEXT §D-09 + §D-10).
/// Exposes a trimmed projection of `Stats` plus a broken-streak copy branch:
/// shame text (D-10) appears ONLY when `currentStreak == 0 && longestStreak >= 3`.
///
/// Shame copy is resolved via `GetBrokenStreakCopyUseCase` (NOT direct access
/// to `NotificationCaptionLibrary`) so this VM honors CLAUDE.md's
/// "VM → tylko UseCase" dependency rule.
@MainActor
@Observable
final class HomeStatsCardViewModel: @unchecked Sendable {

    private(set) var stats: Stats = .empty

    /// Non-nil ⇒ render the shame copy with gray flame (D-10). Nil ⇒
    /// render the regular card (violet flame + current streak).
    var brokenStreakCopy: String? {
        guard stats.currentStreak == 0, stats.longestStreak >= 3 else { return nil }
        return getBrokenStreakCopy.execute(longestStreak: stats.longestStreak)
    }

    @ObservationIgnored @LazyInjected private var observeStats: ObserveStatsUseCase
    @ObservationIgnored @LazyInjected private var getBrokenStreakCopy: GetBrokenStreakCopyUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    init() {
        observeStats.execute()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStats in self?.stats = newStats }
            .store(in: &cancellables)
    }
}
