import XCTest
@testable import DeluluDetox

@MainActor
final class EndSessionUseCaseTests: XCTestCase {
    struct TestError: Error, Equatable {}

    private func makeActive(id: UUID = UUID()) -> SessionRecord {
        SessionRecord(
            id: id,
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }

    func testEndSessionHappyPathClearsShieldStopsMonitoringThenFinalizes() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockCancelNotification = MockCancelSessionEndNotificationUseCase()
        let active = makeActive()
        mockRepo.activeSubject.send(active)

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            cancelEndNotification: mockCancelNotification
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
        let mockCancelNotification = MockCancelSessionEndNotificationUseCase()
        // No active session; make repo throw .noActiveSession.
        mockRepo.finalizeActiveSessionError = SessionStoreError.noActiveSession

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            cancelEndNotification: mockCancelNotification
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
        let mockCancelNotification = MockCancelSessionEndNotificationUseCase()
        mockRepo.activeSubject.send(makeActive())
        mockRepo.finalizeActiveSessionError = TestError()

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            cancelEndNotification: mockCancelNotification
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

    // MARK: - Plan 06-03 (NTF-01 §H2) extensions

    func testCancelsNotification_onCancelledByUserOutcome() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockCancelNotification = MockCancelSessionEndNotificationUseCase()
        let activeId = UUID()
        mockRepo.activeSubject.send(makeActive(id: activeId))

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            cancelEndNotification: mockCancelNotification
        )
        try await uc(outcome: .cancelledByUser, actualEndAt: Date())

        XCTAssertEqual(mockCancelNotification.cancelledSessionIds, [activeId])
    }

    func testCancelsNotification_onBrokenByRevokeOutcome() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockCancelNotification = MockCancelSessionEndNotificationUseCase()
        let activeId = UUID()
        mockRepo.activeSubject.send(makeActive(id: activeId))

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            cancelEndNotification: mockCancelNotification
        )
        try await uc(outcome: .brokenByRevoke, actualEndAt: Date())

        XCTAssertEqual(mockCancelNotification.cancelledSessionIds, [activeId])
    }

    func testDoesNotCancelNotification_onCompletedOutcome() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockCancelNotification = MockCancelSessionEndNotificationUseCase()
        mockRepo.activeSubject.send(makeActive())

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            cancelEndNotification: mockCancelNotification
        )
        try await uc(outcome: .completed, actualEndAt: Date())

        XCTAssertTrue(mockCancelNotification.cancelledSessionIds.isEmpty,
                      "iOS fires the pending session.end trigger naturally on .completed")
    }

    func testDoesNotCancelNotification_whenNoActiveSession() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockCancelNotification = MockCancelSessionEndNotificationUseCase()
        // activeSubject stays at nil
        mockRepo.finalizeActiveSessionError = SessionStoreError.noActiveSession

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            cancelEndNotification: mockCancelNotification
        )
        try await uc(outcome: .cancelledByUser, actualEndAt: Date())

        XCTAssertTrue(mockCancelNotification.cancelledSessionIds.isEmpty,
                      "no active session → nothing to cancel even on abort outcome")
    }
}
