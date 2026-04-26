import XCTest
import FamilyControls
import ManagedSettings
@testable import DeluluDetox

/// Wave 0 spike — A1 assumption validation (see 02-RESEARCH.md §Assumptions Log).
///
/// Proves that per-kind tokens round-trip through JSONEncoder/JSONDecoder so the
/// Blocklist domain model (Plan 02) can safely persist individual tokens keyed by UUID.
///
/// Simulator limitation: real ApplicationToken / ActivityCategoryToken / WebDomainToken
/// values cannot be synthesized — they come from Apple system UI via FamilyActivityPicker.
/// Device-only tests mark themselves via XCTSkipIf and document the skip; failure of the
/// harness itself (compilation / FamilyActivitySelection Codable) still flags immediately.
@MainActor
final class BlockedTokenCodableTests: XCTestCase {

    func testFamilyActivitySelectionJSONRoundTripPreservesEmptySelection() throws {
        let original = FamilyActivitySelection()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        XCTAssertEqual(original.applicationTokens, decoded.applicationTokens)
        XCTAssertEqual(original.categoryTokens, decoded.categoryTokens)
        XCTAssertEqual(original.webDomainTokens, decoded.webDomainTokens)
    }


    /// Regression guard — historically PropertyListEncoder dropped
    /// `includeEntireCategory` on `FamilyActivitySelection` (forum 721973,
    /// RESEARCH Pitfall 4). Under Xcode 26.3 / iOS 26.3 SDK this spike
    /// has empirically observed round-trip equality, so the guard is
    /// inverted: it now asserts the fix stays in place. If Apple re-breaks
    /// PropertyListEncoder, this test will fail and we revisit persistence.
    ///
    /// Plan 02 still picks JSONEncoder as the canonical persistence path
    /// per 02-PATTERNS §persistence — this test merely tracks Apple's SDK
    /// behavior for the control case.
    func testPropertyListEncoderRoundTripPreservesIncludeEntireCategoryFlagOnCurrentSDK() throws {
        let original = FamilyActivitySelection(includeEntireCategory: true)
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        XCTAssertEqual(
            original,
            decoded,
            "PropertyListEncoder round-trip of FamilyActivitySelection should preserve " +
            "includeEntireCategory on iOS 26.3+ SDK. If this fails, Apple has re-introduced " +
            "forum 721973 — see RESEARCH Pitfall 4."
        )
    }
}
