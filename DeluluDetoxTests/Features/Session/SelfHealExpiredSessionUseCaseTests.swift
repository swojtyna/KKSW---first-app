import XCTest
@testable import DeluluDetox

@MainActor
final class SelfHealExpiredSessionUseCaseTests: XCTestCase {

    private func makeActive(id: UUID = UUID(), plannedEnd: Date) -> SessionRecord {
        SessionRecord(
            id: id,
            blocklistId: UUID(),
            startedAt: plannedEnd.addingTimeInterval(-1800),
            plannedEndAt: plannedEnd,
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }

    func testSelfHealFinalizesWhenActiveSessionIsExpired() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plannedEnd = now.addingTimeInterval(-60)   // 60s in the past
        mockRepo.activeSubject.send(makeActive(plannedEnd: plannedEnd))

        let uc = SelfHealExpiredSessionUseCaseImpl(repository: mockRepo, endSession: mockEnd)
        let healed = try await uc(now: now)

        XCTAssertTrue(healed)
        XCTAssertEqual(mockEnd.callCount, 1)
        XCTAssertEqual(mockEnd.lastOutcome, .completed)
        // actualEndAt is capped at plannedEndAt (not wall-clock now).
        XCTAssertEqual(mockEnd.lastActualEndAt, plannedEnd)
    }

    func testSelfHealIsNoOpWhenActiveSessionIsStillRunning() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plannedEnd = now.addingTimeInterval(60)   // 60s in the future
        mockRepo.activeSubject.send(makeActive(plannedEnd: plannedEnd))

        let uc = SelfHealExpiredSessionUseCaseImpl(repository: mockRepo, endSession: mockEnd)
        let healed = try await uc(now: now)

        XCTAssertFalse(healed)
        XCTAssertEqual(mockEnd.callCount, 0)
    }

    func testSelfHealIsNoOpWhenNoActiveSession() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        // activeSubject stays nil.

        let uc = SelfHealExpiredSessionUseCaseImpl(repository: mockRepo, endSession: mockEnd)
        let healed = try await uc(now: Date())

        XCTAssertFalse(healed)
        XCTAssertEqual(mockEnd.callCount, 0)
    }
}
