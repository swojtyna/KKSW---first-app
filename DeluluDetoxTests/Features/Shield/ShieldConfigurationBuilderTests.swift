import XCTest
import UIKit
@testable import DeluluDetox

/// Tests for SHL-01 (branded config) + SHL-02 (fallback). Plan 02 must:
///   1) Implement `ShieldConfigurationBuilder` (struct with one method
///      `make(remainingMinutes: Int?) -> ShieldConfiguration`) in the main-app
///      target so XCTest can drive it; the actual extension just calls into it.
///   2) Make the test class compile by removing the XCTSkip lines and asserting
///      against the real builder output.
///
/// Until Plan 02 ships, these tests skip — keeping the suite green.
final class ShieldConfigurationBuilderTests: XCTestCase {
    func testActiveBranch_titleIsSerio() throws {
        try XCTSkipIf(true, "Plan 02 will implement ShieldConfigurationBuilder. Expected: title.text == \"Serio?\" when remainingMinutes != nil.")
    }
    func testActiveBranch_subtitleContainsRemainingMinutes() throws {
        try XCTSkipIf(true, "Plan 02 will implement subtitle. Expected: subtitle.text contains \"30 min\" when remainingMinutes == 30.")
    }
    func testFallbackBranch_titleIsZablokowane() throws {
        try XCTSkipIf(true, "Plan 02 will implement fallback branch. Expected: title.text == \"Zablokowane\" when remainingMinutes == nil.")
    }
    func testFallbackBranch_primaryButtonLabelIsOtworzDeluluDetox() throws {
        try XCTSkipIf(true, "Plan 02 will implement fallback. Expected: primaryButtonLabel.text == \"Otwórz DeluluDetox\".")
    }
    func testIconIsNonNilAndWhiteTinted() throws {
        try XCTSkipIf(true, "Plan 02 will render hand.raised.fill SF Symbol via UIImage(systemName:withConfiguration:).withTintColor(.white, renderingMode: .alwaysOriginal). Expected: icon != nil.")
    }
}
