import XCTest
@testable import DeluluDetox

@MainActor
final class FinalizeSessionFromMarkerUseCaseTests: XCTestCase {

    private func makeActive(id: UUID, plannedEnd: Date = Date().addingTimeInterval(1800)) -> SessionRecord {
        SessionRecord(
            id: id,
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: plannedEnd,
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }

    func testFinalizeFromMarkerConsumesMarkerAndEndsSessionWhenIdsMatch() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()

        let sessionId = UUID()
        let plannedEnd = Date(timeIntervalSince1970: 1_700_000_000 + 1800)
        mockRepo.activeSubject.send(makeActive(id: sessionId, plannedEnd: plannedEnd))
        mockRepo.stubbedConsumedMarker = SessionFinalizeMarker(
            sessionId: sessionId,
            finalizedAt: plannedEnd,
            source: .damIntervalDidEnd
        )

        let uc = FinalizeSessionFromMarkerUseCaseImpl(repository: mockRepo, endSession: mockEnd)
        let now = plannedEnd.addingTimeInterval(5)  // caller clock slightly after planned end
        let finalized = try await uc(now: now)

        XCTAssertTrue(finalized)
        XCTAssertEqual(mockRepo.consumeFinalizeMarkerCallCount, 1)
        XCTAssertEqual(mockEnd.callCount, 1)
        XCTAssertEqual(mockEnd.lastOutcome, .completed)
        // actualEndAt is capped at plannedEndAt.
        XCTAssertEqual(mockEnd.lastActualEndAt, plannedEnd)
    }

    func testFinalizeFromMarkerIgnoresStaleMarker() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()

        let activeId = UUID()
        let staleId = UUID()
        mockRepo.activeSubject.send(makeActive(id: activeId))
        mockRepo.stubbedConsumedMarker = SessionFinalizeMarker(
            sessionId: staleId,
            finalizedAt: Date(),
            source: .damIntervalDidEnd
        )

        let uc = FinalizeSessionFromMarkerUseCaseImpl(repository: mockRepo, endSession: mockEnd)
        let finalized = try await uc(now: Date())

        XCTAssertFalse(finalized)
        XCTAssertEqual(mockRepo.consumeFinalizeMarkerCallCount, 1)  // destructive consume
        XCTAssertEqual(mockEnd.callCount, 0)
    }

    func testFinalizeFromMarkerIsNoOpWhenNoMarkerExists() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        // stubbedConsumedMarker stays nil.

        let uc = FinalizeSessionFromMarkerUseCaseImpl(repository: mockRepo, endSession: mockEnd)
        let finalized = try await uc(now: Date())

        XCTAssertFalse(finalized)
        XCTAssertEqual(mockRepo.consumeFinalizeMarkerCallCount, 1)
        XCTAssertEqual(mockEnd.callCount, 0)
    }
}
