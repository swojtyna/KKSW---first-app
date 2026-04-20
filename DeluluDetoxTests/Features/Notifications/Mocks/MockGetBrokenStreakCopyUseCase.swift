import Foundation
@testable import DeluluDetox

/// Test double for `GetBrokenStreakCopyUseCase`. Default returns a deterministic
/// Polish shame copy derived from `longestStreak`; tests override `stub` to
/// assert on custom return values.
final class MockGetBrokenStreakCopyUseCase: GetBrokenStreakCopyUseCase, @unchecked Sendable {
    var stub: (Int) -> String = { longest in "Straciłeś \(longest)-dniową serię. Test." }

    func callAsFunction(longestStreak: Int) -> String {
        stub(longestStreak)
    }
}
