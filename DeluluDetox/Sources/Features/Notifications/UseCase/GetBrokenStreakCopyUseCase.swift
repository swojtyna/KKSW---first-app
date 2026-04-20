import Foundation

/// Thin pass-through so ViewModels don't reach for `NotificationCaptionLibrary`
/// directly (VM → only UC rule per CLAUDE.md Architecture section).
/// Resolves the shame string shown on the Home card when a streak breaks
/// (CONTEXT §D-10).
protocol GetBrokenStreakCopyUseCase: Sendable {
    func callAsFunction(longestStreak: Int) -> String
}

final class GetBrokenStreakCopyUseCaseImpl: GetBrokenStreakCopyUseCase {
    private let captions: NotificationCaptionLibrary

    init(captions: NotificationCaptionLibrary) {
        self.captions = captions
    }

    func callAsFunction(longestStreak: Int) -> String {
        captions.brokenStreakCopy(longestStreak: longestStreak, hash: longestStreak)
    }
}
