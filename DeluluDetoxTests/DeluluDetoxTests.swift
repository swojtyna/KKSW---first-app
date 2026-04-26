import Testing
@testable import DeluluDetox

// Cross-cutting smoke tests for core domain types.
// Feature-specific tests live in Features/<Feature>/...

@Test func sessionDurationPreset30IsValid() {
    let d = SessionDuration.preset(30)
    #expect(d != nil)
    #expect(d?.seconds == 1800)
}

@Test func blocklistEmptyHasNoRecordsAndNoRepairNeeded() {
    let list = Blocklist.empty()
    #expect(list.records.isEmpty)
    #expect(!list.needsRepair)
}
