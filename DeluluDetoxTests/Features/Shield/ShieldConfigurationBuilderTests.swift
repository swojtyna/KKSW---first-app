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

    func testIconIsNonNilAndWhiteTinted() {
        XCTAssertNotNil(builder.make(remainingMinutes: 30).icon)
        XCTAssertNotNil(builder.make(remainingMinutes: nil).icon)
    }
}
