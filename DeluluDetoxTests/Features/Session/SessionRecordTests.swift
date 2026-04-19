import XCTest
@testable import DeluluDetox

@MainActor
final class SessionRecordTests: XCTestCase {

    // MARK: SessionOutcome

    func testSessionOutcomeRawValuesMatchContractStrings() throws {
        XCTAssertEqual(SessionOutcome.completed.rawValue, "completed")
        XCTAssertEqual(SessionOutcome.cancelledByUser.rawValue, "cancelled_by_user")
        XCTAssertEqual(SessionOutcome.brokenByRevoke.rawValue, "broken_by_revoke")

        // Confirm JSON shape is the raw string (String-rawValue enums encode to the raw value).
        let data = try JSONEncoder().encode(SessionOutcome.cancelledByUser)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"cancelled_by_user\"")
    }

    func testSessionOutcomeRoundTripsThroughCodable() throws {
        for outcome in [SessionOutcome.completed, .cancelledByUser, .brokenByRevoke] {
            let data = try JSONEncoder().encode(outcome)
            let decoded = try JSONDecoder().decode(SessionOutcome.self, from: data)
            XCTAssertEqual(decoded, outcome)
        }
    }

    // MARK: SessionDuration

    func testSessionDurationAcceptsAllFourPresets() {
        XCTAssertEqual(SessionDuration.preset(15)?.seconds, 15 * 60)
        XCTAssertEqual(SessionDuration.preset(30)?.seconds, 30 * 60)
        XCTAssertEqual(SessionDuration.preset(60)?.seconds, 60 * 60)
        XCTAssertEqual(SessionDuration.preset(90)?.seconds, 90 * 60)
    }

    func testSessionDurationAcceptsBoundarySeconds() {
        XCTAssertNotNil(SessionDuration(seconds: 15 * 60))        // 15 min lower (DeviceActivitySchedule min)
        XCTAssertNotNil(SessionDuration(seconds: 8 * 60 * 60))    // 8 h upper
    }

    func testSessionDurationRejectsOutOfRange() {
        XCTAssertNil(SessionDuration(seconds: 15 * 60 - 1))        // 14 min 59 s
        XCTAssertNil(SessionDuration(seconds: 8 * 60 * 60 + 1))    // 8 h + 1 s
    }

    func testSessionDurationRejectsNegativeOrZero() {
        XCTAssertNil(SessionDuration(seconds: 0))
        XCTAssertNil(SessionDuration(seconds: -1))
    }

    func testSessionDurationRoundTripsThroughCodable() throws {
        guard let duration = SessionDuration.preset(30) else { return XCTFail("preset 30 nil") }
        let data = try JSONEncoder().encode(duration)
        let decoded = try JSONDecoder().decode(SessionDuration.self, from: data)
        XCTAssertEqual(decoded, duration)
    }

    // MARK: SessionRecord

    func testSessionRecordJSONRoundTripPreservesAllFields() throws {
        let id = UUID()
        let blocklistId = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_001_800)  // +30 min
        let original = SessionRecord(
            id: id,
            blocklistId: blocklistId,
            startedAt: start,
            plannedEndAt: end,
            plannedDurationSeconds: 1800,
            appVersion: "1.0"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionRecord.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.blocklistId, blocklistId)
        XCTAssertEqual(decoded.startedAt, start)
        XCTAssertEqual(decoded.plannedEndAt, end)
        XCTAssertEqual(decoded.plannedDurationSeconds, 1800)
        XCTAssertNil(decoded.actualEndAt)
        XCTAssertNil(decoded.outcome)
        XCTAssertEqual(decoded.appVersion, "1.0")
    }

    func testSessionRecordIsActiveIsTrueWhenOutcomeAndActualEndAreNil() {
        let record = SessionRecord(
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "1.0"
        )
        XCTAssertTrue(record.isActive)
    }

    func testSessionRecordIsActiveIsFalseAfterFinalize() {
        var record = SessionRecord(
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "1.0"
        )
        record.actualEndAt = Date()
        record.outcome = .completed
        XCTAssertFalse(record.isActive)
    }

    // MARK: SessionFinalizeMarker

    func testSessionFinalizeMarkerRoundTripsThroughCodable() throws {
        let marker = SessionFinalizeMarker(
            sessionId: UUID(),
            finalizedAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .damIntervalDidEnd
        )
        let data = try JSONEncoder().encode(marker)
        let decoded = try JSONDecoder().decode(SessionFinalizeMarker.self, from: data)
        XCTAssertEqual(decoded, marker)
        XCTAssertEqual(decoded.source.rawValue, "dam_interval_did_end")
    }

    // MARK: SessionPaths

    func testSessionPathsConstantsMatchContract() {
        XCTAssertEqual(SessionPaths.appGroupIdentifier, "group.com.kksw.DeluluDetox")
        XCTAssertEqual(SessionPaths.activeSessionFileName, "active_session.json")
        XCTAssertEqual(SessionPaths.historyFileName, "sessions.json")
        XCTAssertEqual(SessionPaths.finalizeMarkerFileName, "session_finalize_marker.json")
    }
}
