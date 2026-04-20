import XCTest
@testable import DeluluDetox

/// Plan 05-02 lands these assertions.
final class CreateOrUpdateScheduleUseCaseTests: XCTestCase {

    func testCreateAssignsNewUUIDAndPersists() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: UC(schedule: draft without id / draft id=nil flow) → repo.upsert called with newly-generated UUID; returns Schedule with non-nil id.")
    }

    func testUpdatePreservesExistingId() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: UC(schedule: existing id=X) → repo.upsert keeps id=X; no new UUID generated.")
    }

    func testTriggersSyncAfterUpsert() throws {
        try XCTSkipIf(true, "Stub — Plan 05-02 replaces with real assertion. Expected: UC calls sync(schedule:) after repo.upsert succeeds so editor 'Save' → immediate DAS registration happens in one flow.")
    }
}
