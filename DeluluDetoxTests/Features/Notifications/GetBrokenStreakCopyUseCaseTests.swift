import XCTest
@testable import DeluluDetox

/// Verifies the thin UC wrapper routes through `NotificationCaptionLibrary.brokenStreakCopy(longestStreak:hash:)`
/// and uses `longestStreak` itself as the rotation hash (deterministic per longest streak).
final class GetBrokenStreakCopyUseCaseTests: XCTestCase {

    func testCallAsFunction_returnsCaptionForLongestStreak() {
        let captions = NotificationCaptionLibrary()
        let sut = GetBrokenStreakCopyUseCaseImpl(captions: captions)

        let copy = sut(longestStreak: 12)

        XCTAssertTrue(copy.contains("12"), "expected '12' in `\(copy)`")
    }

    func testCallAsFunction_returnsOneOfLibraryCaptions() {
        let captions = NotificationCaptionLibrary()
        let sut = GetBrokenStreakCopyUseCaseImpl(captions: captions)

        let copy = sut(longestStreak: 12)

        // Any of the 3 library templates, post-format, should be reachable via the hash route.
        let interpolated = captions.brokenStreakCaptions.map { String(format: $0, 12) }
        XCTAssertTrue(interpolated.contains(copy), "copy must be one of \(interpolated), got `\(copy)`")
    }
}
