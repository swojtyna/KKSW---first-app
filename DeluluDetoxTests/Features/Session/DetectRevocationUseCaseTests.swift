import XCTest
@preconcurrency import FamilyControls
@testable import DeluluDetox

@MainActor
final class DetectRevocationUseCaseTests: XCTestCase {

    private func makeActive() -> SessionRecord {
        SessionRecord(
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }

    func testDetectRevocationFinalizesWhenActiveAndNotApproved() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        mockRepo.activeSubject.send(makeActive())

        let uc = DetectRevocationUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            authorizationStatusProvider: { .denied }
        )
        let now = Date(timeIntervalSince1970: 1_700_000_500)
        let finalized = try await uc(now: now)

        XCTAssertTrue(finalized)
        XCTAssertEqual(mockEnd.callCount, 1)
        XCTAssertEqual(mockEnd.lastOutcome, .brokenByRevoke)
        XCTAssertEqual(mockEnd.lastActualEndAt, now)
    }

    func testDetectRevocationIsNoOpWhenActiveAndApproved() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        mockRepo.activeSubject.send(makeActive())

        let uc = DetectRevocationUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            authorizationStatusProvider: { .approved }
        )
        let finalized = try await uc(now: Date())

        XCTAssertFalse(finalized)
        XCTAssertEqual(mockEnd.callCount, 0)
    }

    func testDetectRevocationIsNoOpWhenNoActiveSession() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        // No active session.

        let uc = DetectRevocationUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            authorizationStatusProvider: { .denied }
        )
        let finalized = try await uc(now: Date())

        XCTAssertFalse(finalized)
        XCTAssertEqual(mockEnd.callCount, 0)
    }
}
