import Foundation
import Testing
@testable import DeluluDetox

@Suite("GetBrokenStreakCopyUseCase")
struct GetBrokenStreakCopyUseCaseTests {

    @Test("returns caption containing longestStreak value")
    func callAsFunctionReturnsCaptionForLongestStreak() {
        let captions = NotificationCaptionLibrary()
        let sut = GetBrokenStreakCopyUseCaseImpl(captions: captions)

        let copy = sut(longestStreak: 12)

        #expect(copy.contains("12"), "expected '12' in `\(copy)`")
    }

    @Test("returns one of the library captions")
    func callAsFunctionReturnsOneOfLibraryCaptions() {
        let captions = NotificationCaptionLibrary()
        let sut = GetBrokenStreakCopyUseCaseImpl(captions: captions)

        let copy = sut(longestStreak: 12)

        let interpolated = captions.brokenStreakCaptions.map { String(format: $0, 12) }
        #expect(interpolated.contains(copy), "copy must be one of \(interpolated), got `\(copy)`")
    }
}
