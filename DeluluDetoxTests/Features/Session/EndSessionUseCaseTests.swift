import XCTest
@testable import DeluluDetox

@MainActor
final class EndSessionUseCaseTests: XCTestCase {
    struct TestError: Error, Equatable {}

    func testEndSessionHappyPathClearsShieldStopsMonitoringThenFinalizes() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let active = SessionRecord(
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
        mockRepo.activeSubject.send(active)

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring
        )
        let endDate = Date()
        try await uc(outcome: .completed, actualEndAt: endDate)

        XCTAssertEqual(mockShield.clearShieldCallCount, 1)
        XCTAssertEqual(mockMonitoring.stopActivityMonitoringCallCount, 1)
        XCTAssertEqual(mockRepo.finalizeActiveSessionCallCount, 1)
        XCTAssertEqual(mockRepo.finalizeActiveSessionLastOutcome, .completed)
        XCTAssertEqual(mockRepo.finalizeActiveSessionLastActualEndAt, endDate)
    }

    func testEndSessionIsNoOpWhenNoActiveSession() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        // No active session; make repo throw .noActiveSession.
        mockRepo.finalizeActiveSessionError = SessionStoreError.noActiveSession

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring
        )
        try await uc(outcome: .completed, actualEndAt: Date())

        // Defense-in-depth — clearShield/stopMonitoring still called.
        XCTAssertEqual(mockShield.clearShieldCallCount, 1)
        XCTAssertEqual(mockMonitoring.stopActivityMonitoringCallCount, 1)
        // Finalize was attempted, threw noActiveSession; UC swallowed it (no throw).
        XCTAssertEqual(mockRepo.finalizeActiveSessionCallCount, 1)
    }

    func testEndSessionPropagatesRepoFinalizeError() async {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        mockRepo.activeSubject.send(SessionRecord(
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        ))
        mockRepo.finalizeActiveSessionError = TestError()

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring
        )
        do {
            try await uc(outcome: .completed, actualEndAt: Date())
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(mockShield.clearShieldCallCount, 1)
            XCTAssertEqual(mockMonitoring.stopActivityMonitoringCallCount, 1)
            XCTAssertTrue(error is TestError)
        }
    }
}
