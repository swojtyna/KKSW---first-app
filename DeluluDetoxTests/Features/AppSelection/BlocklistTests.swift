import Foundation
import FamilyControls
import Testing
@testable import DeluluDetox

@Suite("Blocklist")
struct BlocklistTests {

    @Test("empty blocklist has no records and empty selection")
    func emptyBlocklistHasNoRecordsAndEmptySelection() {
        let list = Blocklist.empty()
        #expect(list.records.isEmpty)
        #expect(list.lastSelection.applicationTokens.isEmpty)
        #expect(list.lastSelection.categoryTokens.isEmpty)
        #expect(list.lastSelection.webDomainTokens.isEmpty)
        #expect(!list.needsRepair)
        #expect(list.name == nil)
    }

    @Test("JSON round-trip preserves core fields")
    func blocklistJSONRoundTripPreservesCoreFields() throws {
        let id = UUID()
        var original = Blocklist.empty(id: id)
        original.name = "Work"
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Blocklist.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.name == "Work")
        #expect(decoded.records.count == 0)
        #expect(decoded.needsRepair == false)
    }

    @Test("merging with empty selection yields empty records and caches selection")
    func mergingWithEmptySelectionYieldsEmptyRecordsAndCachesSelection() {
        let selection = FamilyActivitySelection()
        let result = Blocklist.empty().merging(selection: selection)
        #expect(result.records.isEmpty)
        #expect(result.lastSelection == selection)
        #expect(!result.needsRepair)
    }

    @Test("merging drops records not present in new selection")
    func mergingPreservesExistingRecordUUIDForIdenticalEncodedToken() {
        let stableTokenBytes = Data([0x01, 0x02, 0x03])
        let fixedUUID = UUID()
        var original = Blocklist.empty()
        original.records = [
            TokenRecord(id: fixedUUID, kind: .application, encodedToken: stableTokenBytes, lastSeenAt: Date(timeIntervalSince1970: 0))
        ]
        let next = FamilyActivitySelection()
        let result = original.merging(selection: next)
        #expect(result.records.isEmpty, "Records not present in new selection must be dropped.")
    }

    @Test("merging drops records whose token is not in new selection")
    func mergingDropsRecordsWhoseTokenIsNotInNewSelection() {
        var original = Blocklist.empty()
        original.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0xAA]), lastSeenAt: Date()),
            TokenRecord(id: UUID(), kind: .category, encodedToken: Data([0xBB]), lastSeenAt: Date()),
        ]
        let result = original.merging(selection: FamilyActivitySelection())
        #expect(result.records.isEmpty)
    }

    @Test("TokenRecord JSON round-trip preserves id and kind")
    func tokenRecordJSONRoundTripPreservesIdAndKind() throws {
        let original = TokenRecord(
            id: UUID(), kind: .webDomain,
            encodedToken: Data([0xDE, 0xAD]), lastSeenAt: Date()
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenRecord.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.kind == original.kind)
        #expect(decoded.encodedToken == original.encodedToken)
    }

    @Test("application-kind TokenRecord returns nil for category/web tokens")
    func tokenRecordCategoryTokenReturnsNilForApplicationKind() {
        let rec = TokenRecord(id: UUID(), kind: .application, encodedToken: Data(), lastSeenAt: Date())
        #expect(rec.categoryToken() == nil)
        #expect(rec.webDomainToken() == nil)
    }

    @Test("reconcileTokenPointers bumps updatedAt and keeps records")
    func reconcileTokenPointersBumpsUpdatedAtButKeepsRecords() {
        var original = Blocklist.empty()
        original.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: Date()),
        ]
        let initialUpdatedAt = original.updatedAt
        Thread.sleep(forTimeInterval: 0.01)
        let result = original.reconcileTokenPointers()
        #expect(result.updatedAt > initialUpdatedAt)
        #expect(result.records.count == 1)
        #expect(result.records.first?.id == original.records.first?.id)
    }
}
