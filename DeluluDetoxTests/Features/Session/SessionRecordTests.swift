import Foundation
import Testing
@testable import DeluluDetox

@Suite("SessionRecord model")
struct SessionRecordTests {

    // MARK: - SessionOutcome

    @Test("outcome raw values match contract strings")
    func sessionOutcomeRawValuesMatchContractStrings() throws {
        #expect(SessionOutcome.completed.rawValue == "completed")
        #expect(SessionOutcome.cancelledByUser.rawValue == "cancelled_by_user")
        #expect(SessionOutcome.brokenByRevoke.rawValue == "broken_by_revoke")

        let data = try JSONEncoder().encode(SessionOutcome.cancelledByUser)
        #expect(String(data: data, encoding: .utf8) == "\"cancelled_by_user\"")
    }

    @Test("all outcomes round-trip through Codable")
    func sessionOutcomeRoundTripsThroughCodable() throws {
        for outcome in [SessionOutcome.completed, .cancelledByUser, .brokenByRevoke] {
            let data = try JSONEncoder().encode(outcome)
            let decoded = try JSONDecoder().decode(SessionOutcome.self, from: data)
            #expect(decoded == outcome)
        }
    }

    // MARK: - SessionDuration

    @Test("all four presets are valid")
    func sessionDurationAcceptsAllFourPresets() {
        #expect(SessionDuration.preset(15)?.seconds == 15 * 60)
        #expect(SessionDuration.preset(30)?.seconds == 30 * 60)
        #expect(SessionDuration.preset(60)?.seconds == 60 * 60)
        #expect(SessionDuration.preset(90)?.seconds == 90 * 60)
    }

    @Test("boundary seconds (15 min and 8 h) are accepted")
    func sessionDurationAcceptsBoundarySeconds() {
        #expect(SessionDuration(seconds: 15 * 60) != nil)
        #expect(SessionDuration(seconds: 8 * 60 * 60) != nil)
    }

    @Test("out-of-range seconds are rejected")
    func sessionDurationRejectsOutOfRange() {
        #expect(SessionDuration(seconds: 15 * 60 - 1) == nil)
        #expect(SessionDuration(seconds: 8 * 60 * 60 + 1) == nil)
    }

    @Test("negative and zero seconds are rejected")
    func sessionDurationRejectsNegativeOrZero() {
        #expect(SessionDuration(seconds: 0) == nil)
        #expect(SessionDuration(seconds: -1) == nil)
    }

    @Test("SessionDuration round-trips through Codable")
    func sessionDurationRoundTripsThroughCodable() throws {
        let duration = try #require(SessionDuration.preset(30))
        let data = try JSONEncoder().encode(duration)
        let decoded = try JSONDecoder().decode(SessionDuration.self, from: data)
        #expect(decoded == duration)
    }

    // MARK: - SessionRecord

    @Test("JSON round-trip preserves all fields")
    func sessionRecordJSONRoundTripPreservesAllFields() throws {
        let id = UUID()
        let blocklistId = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_001_800)
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

        #expect(decoded.id == id)
        #expect(decoded.blocklistId == blocklistId)
        #expect(decoded.startedAt == start)
        #expect(decoded.plannedEndAt == end)
        #expect(decoded.plannedDurationSeconds == 1800)
        #expect(decoded.actualEndAt == nil)
        #expect(decoded.outcome == nil)
        #expect(decoded.appVersion == "1.0")
    }

    @Test("isActive is true when outcome and actualEndAt are nil")
    func sessionRecordIsActiveIsTrueWhenOutcomeAndActualEndAreNil() {
        let record = SessionRecord(
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "1.0"
        )
        #expect(record.isActive)
    }

    @Test("isActive is false after finalize")
    func sessionRecordIsActiveIsFalseAfterFinalize() {
        var record = SessionRecord(
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "1.0"
        )
        record.actualEndAt = Date()
        record.outcome = .completed
        #expect(!record.isActive)
    }

    // MARK: - SessionFinalizeMarker

    @Test("SessionFinalizeMarker round-trips through Codable")
    func sessionFinalizeMarkerRoundTripsThroughCodable() throws {
        let marker = SessionFinalizeMarker(
            sessionId: UUID(),
            finalizedAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .damIntervalDidEnd
        )
        let data = try JSONEncoder().encode(marker)
        let decoded = try JSONDecoder().decode(SessionFinalizeMarker.self, from: data)
        #expect(decoded == marker)
        #expect(decoded.source.rawValue == "dam_interval_did_end")
    }

    // MARK: - SessionPaths

    @Test("SessionPaths constants match contract")
    func sessionPathsConstantsMatchContract() {
        #expect(SessionPaths.appGroupIdentifier == "group.com.kksw.DeluluDetox")
        #expect(SessionPaths.activeSessionFileName == "active_session.json")
        #expect(SessionPaths.historyFileName == "sessions.json")
        #expect(SessionPaths.finalizeMarkerFileName == "session_finalize_marker.json")
    }
}
