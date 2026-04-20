import XCTest
import ManagedSettingsUI
import UIKit
@testable import DeluluDetox

/// SHL-01 (branded config) + SHL-02 (fallback) — pure builder unit tests.
final class ShieldConfigurationBuilderTests: XCTestCase {

    private let builder = ShieldConfigurationBuilder()

    func testActiveBranch_titleIsSerio() {
        let config = builder.make(remainingMinutes: 30)
        XCTAssertEqual(config.title?.text, "Serio?")
    }

    func testActiveBranch_subtitleContainsRemainingMinutes() {
        let config = builder.make(remainingMinutes: 30)
        XCTAssertTrue(
            config.subtitle?.text.contains("30 min") ?? false,
            "Expected subtitle to contain \"30 min\", got: \(config.subtitle?.text ?? "nil")"
        )
    }

    func testFallbackBranch_titleIsZablokowane() {
        let config = builder.make(remainingMinutes: nil)
        XCTAssertEqual(config.title?.text, "Zablokowane")
    }

    func testFallbackBranch_primaryButtonLabelIsOtworzDeluluDetox() {
        let config = builder.make(remainingMinutes: nil)
        XCTAssertEqual(config.primaryButtonLabel?.text, "Otwórz DeluluDetox")
    }

    func testFallbackBranch_subtitleMatchesContract() {
        // SHL-02 / CONTEXT §D-12: fallback subtitle must match exact sarcastic
        // copy — any drift would change what the user sees when iOS invokes the
        // shield for an unknown / stale token.
        let config = builder.make(remainingMinutes: nil)
        let expected = "Zamknij i zrób coś mądrzejszego."
        XCTAssertEqual(config.subtitle?.text, expected)
    }

    func testFallbackBranch_subtitleContainsNoDigit_provingActiveBranchDidNotLeak() {
        // SHL-02 regression guard: the fallback branch must NEVER surface a
        // remaining-minutes number. If this test ever turns red, the active
        // branch copy has leaked into the fallback path — check the
        // ShieldConfigurationBuilder make(remainingMinutes:) switch/if guard.
        let config = builder.make(remainingMinutes: nil)
        let subtitle = config.subtitle?.text ?? ""
        let digits = subtitle.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
        XCTAssertTrue(
            digits.isEmpty,
            "Fallback subtitle leaked a digit: \(subtitle)"
        )
    }

    func testIconIsNonNilAndWhiteTinted() {
        XCTAssertNotNil(builder.make(remainingMinutes: 30).icon)
        XCTAssertNotNil(builder.make(remainingMinutes: nil).icon)
    }
}
