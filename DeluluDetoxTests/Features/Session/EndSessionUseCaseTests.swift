import Foundation
import Testing
@testable import DeluluDetox

@Suite("EndSessionUseCase")
@MainActor
struct EndSessionUseCaseTests {

    struct TestError: Error, Equatable {}

    @Test("happy path: clears shield, stops monitoring, then finalizes")
    func endSessionHappyPathClearsShieldStopsMonitoringThenFinalizes() async throws {
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
        try await uc.execute(outcome: .completed, actualEndAt: endDate)

        #expect(mockShield.clearShieldCallCount == 1)
        #expect(mockMonitoring.stopActivityMonitoringCallCount == 1)
        #expect(mockRepo.finalizeActiveSessionCallCount == 1)
        #expect(mockRepo.finalizeActiveSessionLastOutcome == .completed)
        #expect(mockRepo.finalizeActiveSessionLastActualEndAt == endDate)
    }

    @Test("no-op when no active session (swallows noActiveSession error)")
    func endSessionIsNoOpWhenNoActiveSession() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockCancelNotification = MockCancelSessionEndNotificationUseCase()
        mockRepo.finalizeActiveSessionError = SessionStoreError.noActiveSession

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            cancelEndNotification: mockCancelNotification
        )
        try await uc.execute(outcome: .completed, actualEndAt: Date())

        #expect(mockShield.clearShieldCallCount == 1)
        #expect(mockMonitoring.stopActivityMonitoringCallCount == 1)
        #expect(mockRepo.finalizeActiveSessionCallCount == 1)
    }

    @Test("propagates unexpected repo finalize error")
    func endSessionPropagatesRepoFinalizeError() async {
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
            try await uc.execute(outcome: .completed, actualEndAt: Date())
            Issue.record("expected throw")
        } catch {
            #expect(mockShield.clearShieldCallCount == 1)
            #expect(mockMonitoring.stopActivityMonitoringCallCount == 1)
            #expect(error is TestError)
        }
    }

    // MARK: - Notification cancellation

    @Test("cancels notification on cancelledByUser outcome")
    func cancelsNotification_onCancelledByUserOutcome() async throws {
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
        try await uc.execute(outcome: .cancelledByUser, actualEndAt: Date())

        #expect(mockCancelNotification.cancelledSessionIds == [activeId])
    }

    @Test("cancels notification on brokenByRevoke outcome")
    func cancelsNotification_onBrokenByRevokeOutcome() async throws {
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
        try await uc.execute(outcome: .brokenByRevoke, actualEndAt: Date())

        #expect(mockCancelNotification.cancelledSessionIds == [activeId])
    }

    @Test("does NOT cancel notification on completed outcome (iOS fires it naturally)")
    func doesNotCancelNotification_onCompletedOutcome() async throws {
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
        try await uc.execute(outcome: .completed, actualEndAt: Date())

        #expect(mockCancelNotification.cancelledSessionIds.isEmpty,
                "iOS fires the pending session.end trigger naturally on .completed")
    }

    @Test("does NOT cancel notification when no active session")
    func doesNotCancelNotification_whenNoActiveSession() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockCancelNotification = MockCancelSessionEndNotificationUseCase()
        mockRepo.finalizeActiveSessionError = SessionStoreError.noActiveSession

        let uc = EndSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            cancelEndNotification: mockCancelNotification
        )
        try await uc.execute(outcome: .cancelledByUser, actualEndAt: Date())

        #expect(mockCancelNotification.cancelledSessionIds.isEmpty,
                "no active session → nothing to cancel even on abort outcome")
    }
}

// MARK: - Private Helpers

private extension EndSessionUseCaseTests {
    func makeActive(id: UUID = UUID()) -> SessionRecord {
        SessionRecord(
            id: id,
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }
}
