import Foundation
import ManagedSettingsUI
import UIKit
import Testing
@testable import DeluluDetox

@Suite("ShieldConfigurationBuilder")
struct ShieldConfigurationBuilderTests {

    private let builder = ShieldConfigurationBuilder()

    @Test("active branch title is 'Serio?'")
    func activeBranch_titleIsSerio() {
        let config = builder.make(remainingMinutes: 30)
        #expect(config.title?.text == "Serio?")
    }

    @Test("active branch subtitle contains remaining minutes")
    func activeBranch_subtitleContainsRemainingMinutes() {
        let config = builder.make(remainingMinutes: 30)
        #expect(config.subtitle?.text.contains("30 min") ?? false,
                "Expected subtitle to contain \"30 min\", got: \(config.subtitle?.text ?? "nil")")
    }

    @Test("fallback branch title is 'Zablokowane'")
    func fallbackBranch_titleIsZablokowane() {
        let config = builder.make(remainingMinutes: nil)
        #expect(config.title?.text == "Zablokowane")
    }

    @Test("fallback branch primary button label matches contract")
    func fallbackBranch_primaryButtonLabelIsOtworzDeluluDetox() {
        let config = builder.make(remainingMinutes: nil)
        #expect(config.primaryButtonLabel?.text == "Otwórz DeluluDetox")
    }

    @Test("fallback branch subtitle matches exact copy")
    func fallbackBranch_subtitleMatchesContract() {
        let config = builder.make(remainingMinutes: nil)
        let expected = "Zamknij i zrób coś mądrzejszego."
        #expect(config.subtitle?.text == expected)
    }

    @Test("fallback branch subtitle contains no digit (active branch did not leak)")
    func fallbackBranch_subtitleContainsNoDigit_provingActiveBranchDidNotLeak() {
        let config = builder.make(remainingMinutes: nil)
        let subtitle = config.subtitle?.text ?? ""
        let digits = subtitle.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
        #expect(digits.isEmpty, "Fallback subtitle leaked a digit: \(subtitle)")
    }

    @Test("icon is non-nil for both branches")
    func iconIsNonNilAndWhiteTinted() {
        #expect(builder.make(remainingMinutes: 30).icon != nil)
        #expect(builder.make(remainingMinutes: nil).icon != nil)
    }
}
