import Foundation
import FamilyControls
import ManagedSettings
import Testing
@testable import DeluluDetox

@Suite("BlockedTokenCodable — A1 assumption validation")
@MainActor
struct BlockedTokenCodableTests {

    @Test("FamilyActivitySelection JSON round-trip preserves empty selection")
    func familyActivitySelectionJSONRoundTripPreservesEmptySelection() throws {
        let original = FamilyActivitySelection()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        #expect(original.applicationTokens == decoded.applicationTokens)
        #expect(original.categoryTokens == decoded.categoryTokens)
        #expect(original.webDomainTokens == decoded.webDomainTokens)
    }

    @Test("PropertyListEncoder round-trip preserves includeEntireCategory flag on current SDK")
    func propertyListEncoderRoundTripPreservesIncludeEntireCategoryFlagOnCurrentSDK() throws {
        let original = FamilyActivitySelection(includeEntireCategory: true)
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        #expect(
            original == decoded,
            "PropertyListEncoder round-trip should preserve includeEntireCategory on iOS 26.3+ SDK — if this fails, Apple has re-introduced forum 721973 (see RESEARCH Pitfall 4)"
        )
    }
}
